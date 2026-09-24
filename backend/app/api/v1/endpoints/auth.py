from typing import Optional
from fastapi import APIRouter, Depends, Request, status
from fastapi.security import HTTPAuthorizationCredentials

from app.core.dependencies import get_auth_service, get_current_user, security_scheme
from app.core.rate_limit import RateLimiter
from app.db.models.user import User
from app.schemas.common import ApiResponse, MessageData
from app.schemas.user import (
    AuthResponse,
    ForgotPasswordRequest,
    LogoutRequest,
    RefreshTokenRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
    UserLogin,
    UserRead,
)
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post(
    "/register",
    response_model=ApiResponse[AuthResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Register new user account",
    dependencies=[Depends(RateLimiter(requests=10, window_seconds=60, action="auth_register"))],
)
async def register(
    request: Request,
    payload: RegisterRequest,
    auth_service: AuthService = Depends(get_auth_service),
) -> ApiResponse[AuthResponse]:
    """Registers a new user and returns JWT token pair with user profile."""
    client_ip = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")

    user, tokens = await auth_service.register(
        user_in=payload,
        client_ip=client_ip,
        user_agent=user_agent,
    )

    return ApiResponse(
        data=AuthResponse(
            access_token=tokens.access_token,
            refresh_token=tokens.refresh_token,
            token_type=tokens.token_type,
            expires_in=tokens.expires_in,
            user=UserRead.model_validate(user),
        )
    )


@router.post(
    "/login",
    response_model=ApiResponse[AuthResponse],
    status_code=status.HTTP_200_OK,
    summary="Authenticate user with credentials",
    dependencies=[Depends(RateLimiter(requests=15, window_seconds=60, action="auth_login"))],
)
async def login(
    request: Request,
    payload: UserLogin,
    auth_service: AuthService = Depends(get_auth_service),
) -> ApiResponse[AuthResponse]:
    """Authenticates credentials and returns JWT token pair with user profile."""
    client_ip = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")

    user, tokens = await auth_service.login(
        credentials=payload,
        client_ip=client_ip,
        user_agent=user_agent,
    )

    return ApiResponse(
        data=AuthResponse(
            access_token=tokens.access_token,
            refresh_token=tokens.refresh_token,
            token_type=tokens.token_type,
            expires_in=tokens.expires_in,
            user=UserRead.model_validate(user),
        )
    )


@router.post(
    "/refresh",
    response_model=ApiResponse[TokenResponse],
    status_code=status.HTTP_200_OK,
    summary="Rotate access and refresh tokens",
    dependencies=[Depends(RateLimiter(requests=30, window_seconds=60, action="auth_refresh"))],
)
async def refresh_tokens(
    request: Request,
    payload: RefreshTokenRequest,
    auth_service: AuthService = Depends(get_auth_service),
) -> ApiResponse[TokenResponse]:
    """Validates refresh token, invalidates it, and returns a new token pair."""
    client_ip = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")

    tokens = await auth_service.refresh_tokens(
        raw_refresh_token=payload.refresh_token,
        client_ip=client_ip,
        user_agent=user_agent,
    )

    return ApiResponse(data=tokens)


@router.post(
    "/logout",
    response_model=ApiResponse[MessageData],
    status_code=status.HTTP_200_OK,
    summary="Revoke active refresh token session",
)
async def logout(
    payload: Optional[LogoutRequest] = None,
    auth_credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme),
    auth_service: AuthService = Depends(get_auth_service),
) -> ApiResponse[MessageData]:
    """Revokes the presented refresh token or invalidates the current session."""
    raw_refresh_token = payload.refresh_token if payload else None
    await auth_service.logout(raw_refresh_token=raw_refresh_token)

    return ApiResponse(
        data=MessageData(message="Successfully logged out")
    )


@router.get(
    "/me",
    response_model=ApiResponse[UserRead],
    status_code=status.HTTP_200_OK,
    summary="Fetch current authenticated user profile",
)
async def get_me(
    current_user: User = Depends(get_current_user),
) -> ApiResponse[UserRead]:
    """Returns safe user identity information for the bearer token."""
    return ApiResponse(data=UserRead.model_validate(current_user))


@router.post(
    "/forgot-password",
    response_model=ApiResponse[MessageData],
    status_code=status.HTTP_200_OK,
    summary="Request password reset token",
    dependencies=[Depends(RateLimiter(requests=5, window_seconds=60, action="auth_forgot_password"))],
)
async def forgot_password(
    payload: ForgotPasswordRequest,
    auth_service: AuthService = Depends(get_auth_service),
) -> ApiResponse[MessageData]:
    """
    Generates a secure password reset token if account exists.
    Returns generic response to prevent email enumeration.
    """
    await auth_service.request_password_reset(email=payload.email)

    return ApiResponse(
        data=MessageData(
            message="If an account exists for this email, a password reset link has been requested."
        )
    )


@router.post(
    "/reset-password",
    response_model=ApiResponse[MessageData],
    status_code=status.HTTP_200_OK,
    summary="Reset account password using valid reset token",
    dependencies=[Depends(RateLimiter(requests=10, window_seconds=60, action="auth_reset_password"))],
)
async def reset_password(
    payload: ResetPasswordRequest,
    auth_service: AuthService = Depends(get_auth_service),
) -> ApiResponse[MessageData]:
    """Validates single-use reset token and updates user password."""
    await auth_service.reset_password(
        raw_token=payload.token,
        new_password=payload.new_password,
    )

    return ApiResponse(
        data=MessageData(message="Password has been successfully reset.")
    )
