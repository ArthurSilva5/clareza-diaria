"""
CACHE SIMPLES EM MEMÓRIA COM TTL (TIME TO LIVE) PARA DADOS ESTÁTICOS.
"""
from __future__ import annotations

import time
from typing import Any, Optional
from threading import Lock


class SimpleCache:
    """
    CACHE EM MEMÓRIA THREAD-SAFE COM TTL.
    """
    
    def __init__(self, default_ttl: int = 300):
        """
        Args:
            default_ttl: TEMPO DE VIDA PADRÃO EM SEGUNDOS (PADRÃO: 5 MINUTOS)
        """
        self._cache: dict[str, tuple[Any, float]] = {}
        self._lock = Lock()
        self.default_ttl = default_ttl
    
    def get(self, key: str) -> Optional[Any]:
        """
        BUSCA UM VALOR NO CACHE.
        
        Args:
            key: CHAVE DO CACHE
            
        Returns:
            VALOR ARMAZENADO OU None SE NÃO EXISTIR OU EXPIRADO
        """
        with self._lock:
            if key not in self._cache:
                return None
            
            value, expiry = self._cache[key]
            
            # VERIFICAR SE EXPIROU
            if time.time() > expiry:
                del self._cache[key]
                return None
            
            return value
    
    def set(self, key: str, value: Any, ttl: Optional[int] = None) -> None:
        """
        ARMAZENA UM VALOR NO CACHE.
        
        Args:
            key: CHAVE DO CACHE
            value: VALOR A ARMAZENAR
            ttl: TEMPO DE VIDA EM SEGUNDOS (USA default_ttl SE None)
        """
        with self._lock:
            expiry = time.time() + (ttl or self.default_ttl)
            self._cache[key] = (value, expiry)
    
    def delete(self, key: str) -> None:
        """
        REMOVE UM VALOR DO CACHE.
        
        Args:
            key: CHAVE DO CACHE
        """
        with self._lock:
            if key in self._cache:
                del self._cache[key]
    
    def clear(self) -> None:
        """LIMPA TODO O CACHE."""
        with self._lock:
            self._cache.clear()
    
    def invalidate_pattern(self, pattern: str) -> None:
        """
        REMOVE TODAS AS CHAVES QUE COMEÇAM COM O PADRÃO.
        
        Args:
            pattern: PADRÃO DE PREFIXO DAS CHAVES
        """
        with self._lock:
            keys_to_delete = [key for key in self._cache.keys() if key.startswith(pattern)]
            for key in keys_to_delete:
                del self._cache[key]
    
    def cleanup_expired(self) -> None:
        """REMOVE ENTRADAS EXPIRADAS DO CACHE."""
        with self._lock:
            current_time = time.time()
            expired_keys = [
                key for key, (_, expiry) in self._cache.items()
                if current_time > expiry
            ]
            for key in expired_keys:
                del self._cache[key]


# INSTÂNCIA GLOBAL DO CACHE
cache = SimpleCache(default_ttl=300)  # 5 MINUTOS PADRÃO

