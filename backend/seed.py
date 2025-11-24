"""
SEED PARA CRIAR DADOS INICIAIS NO BANCO DE DADOS.
CRIA O USUÁRIO ADMIN AUTOMATICAMENTE SE NÃO EXISTIR.
"""
from .extensions import db
from .models import User


def seed_admin_user() -> None:
    """
    CRIA O USUÁRIO ADMIN SE NÃO EXISTIR.
    EMAIL: admin@gmail.com
    SENHA: 123456
    NOME: admin
    PERFIL: Administrador (PERFIL EXCLUSIVO PARA ADMIN)
    ROLE: admin
    """
    admin_email = "admin@gmail.com"
    
    # VERIFICAR SE O ADMIN JÁ EXISTE
    existing_admin = User.query.filter_by(email=admin_email).first()
    
    if existing_admin is None:
        # CRIAR USUÁRIO ADMIN
        admin = User(
            email=admin_email,
            nome_completo="admin",
            perfil="Administrador",
            role="admin",  # ROLE ESPECIAL PARA ADMIN
        )
        admin.set_password("123456")
        
        db.session.add(admin)
        db.session.commit()
        print(f"✅ USUÁRIO ADMIN CRIADO: {admin_email}")
    else:
        print(f"ℹ️  USUÁRIO ADMIN JÁ EXISTE: {admin_email}")


def init_seed(app) -> None:
    """
    INICIALIZA OS SEEDS DO BANCO DE DADOS.
    DEVE SER CHAMADO APÓS O APP SER CRIADO E AS TABELAS ESTAREM PRONTAS.
    """
    try:
        seed_admin_user()
    except Exception as e:
        print(f"❌ ERRO AO EXECUTAR SEED: {e}")

