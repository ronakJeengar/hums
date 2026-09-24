from fastapi import UploadFile
from app.core.errors import BadRequestError


async def read_upload_file_bounded(
    file: UploadFile,
    max_bytes: int,
    error_code: str = "FILE_TOO_LARGE",
    error_message: str = "Uploaded file exceeds maximum allowed size.",
    chunk_size: int = 64 * 1024,
) -> bytes:
    """
    Reads an UploadFile in chunks up to max_bytes.
    
    If the uploaded content exceeds max_bytes, reading terminates immediately
    and raises BadRequestError without consuming additional memory or disk.
    """
    chunks = []
    total_bytes = 0

    while True:
        chunk = await file.read(chunk_size)
        if not chunk:
            break
        total_bytes += len(chunk)
        if total_bytes > max_bytes:
            raise BadRequestError(error_message, code=error_code)
        chunks.append(chunk)

    return b"".join(chunks)
