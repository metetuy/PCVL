from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from dotenv import load_dotenv
import os

# envi yükledik
load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

# Db bağlantısını bu kuruyor. (telefon santrali) once per application
engine = create_engine(DATABASE_URL)

"""
SessionLocal
Engine bağlantıyı kurar, session ise o bağlantı üzerinde konuşmayı yönetir. 
Her HTTP isteği için ayrı bir session açılır, işi biter, kapanır. Neden ayrı ayrı?

Şöyle düşün: aynı anda 100 kullanıcı API'ına istek atıyor. Hepsi aynı session'ı 
paylaşsaydı birbirinin yarım kalmış işlemlerini görürdü. 

Her isteğin kendi izole session'ı olunca bu problem olmaz.
autocommit=False şu anlama gelir: 
veritabanına bir şey yazdığında otomatik kaydolmaz. 
Sen açıkça commit() diyene kadar bekler.

Bu önemli çünkü bazen birden fazla şeyi aynı anda kaydetmen gerekir — 
biri başarılı olup diğeri başarısız olursa ikisini birden geri almak istersin. Buna transaction denir.
"""
SessionLocal = sessionmaker(autocommit = False, autoflush = False, bind = engine)

"""

Base
SQLAlchemy'e "bu bir veritabanı tablosunu temsil eden bir sınıftır" 
demenin yolu Base'den inherit etmek. 
Bunu models.py'da göreceksin
 — class SessionRecord(Base) diyeceksin ve SQLAlchemy otomatik olarak bunu bir tabloya çevirecek.


"""

class Base(DeclarativeBase):
    pass

"""

get_db() ve yield
Bu fonksiyon bir FastAPI dependency. Dependency injection şu demek: "
bu endpoint'in çalışması için şuna ihtiyacı var, sen hallettiysen ver." 
Her endpoint get_db()'yi dependency olarak tanımladığında FastAPI şunu yapar:

SessionLocal() ile yeni bir session açar
O session'ı endpoint'e verir
Endpoint işini bitirir
finally bloğu çalışır, session kapanır — hata olsa bile

yield burada kritik. Normal return kullansaydın finally bloğu çalışmazdı. 
yield ile fonksiyon "şimdilik dur, endpoint bitince geri dön ve temizliği yap"
 diyebiliyor. Bu pattern'e Python'da context manager denir ve backend'de her yerde karşına çıkar.
 
"""

def get_db():

    db=SessionLocal

    try:
        yield db
    finally:
        db.close()