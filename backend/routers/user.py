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

class UserProfileRequest(BaseModel):
    age: int | None = None
    height: float | None = None
    weight: float | None = None
    gender: str | None = None
    allergies: list[str] | None = None
    diet_preference: str | None = None

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

@router.post("/user/profile")
async def sync_user_profile(
    req: UserProfileRequest,
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Kullanıcı profilini Flutter'dan (Firestore'dan) PostgreSQL'e senkronize eder.
    Alerji ve diyet tercihleri de burada güncellenir.
    """
    user = await crud.get_or_create_user(db, uid)
    
    if req.age is not None:
        user.age = req.age
    if req.height is not None:
        user.height = req.height
    if req.weight is not None:
        user.weight = req.weight
    if req.gender is not None:
        user.gender = req.gender
    if req.allergies is not None:
        user.allergies = req.allergies
    if req.diet_preference is not None:
        user.diet_preference = req.diet_preference
        
    await db.commit()
    await db.refresh(user)
    
    return {"success": True, "message": "Profil güncellendi."}
