"""
AKSA Backend — User Endpoint'leri
Kullanıcı hesabı yönetimi ve silme işlemleri.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel

from database import get_db
from auth import get_current_user
import crud

router = APIRouter()

class DeleteUserResponse(BaseModel):
    success: bool
    message: str

@router.delete("/user", response_model=DeleteUserResponse)
async def delete_account(
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Kullanıcının hesabını ve tüm ilişkili verilerini (sağlık, risk, vb.)
    veritabanından kalıcı olarak (hard delete) siler.
    """
    user = await crud.get_or_create_user(db, uid)
    success = await crud.delete_user_completely(db, user)
    
    if success:
        return DeleteUserResponse(success=True, message="Kullanıcı hesabı başarıyla silindi.")
    else:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Kullanıcı silinirken bir hata oluştu."
        )
