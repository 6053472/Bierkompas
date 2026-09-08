-- BierKompas database schema
-- Importeren via phpMyAdmin: open je database -> tabblad "SQL" -> plak dit bestand -> Uitvoeren.

CREATE TABLE IF NOT EXISTS users (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS user_consents (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    terms_version VARCHAR(20) NOT NULL,
    privacy_version VARCHAR(20) NOT NULL,
    accepted_at TIMESTAMP NOT NULL,
    age_confirmed TINYINT(1) NOT NULL DEFAULT 0,
    lawful_alcohol_use TINYINT(1) NOT NULL DEFAULT 0,
    accurate_account_data TINYINT(1) NOT NULL DEFAULT 0,
    personal_account TINYINT(1) NOT NULL DEFAULT 0,
    credentials_secure TINYINT(1) NOT NULL DEFAULT 0,
    no_impersonation TINYINT(1) NOT NULL DEFAULT 0,
    CONSTRAINT fk_user_consents_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_consent_version (user_id, terms_version, privacy_version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Klaar voor later (Favorieten-scherm), nog niet gekoppeld aan een API-endpoint.
CREATE TABLE IF NOT EXISTS favorites (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    item_type VARCHAR(50) NOT NULL,   -- bv. 'beer' of 'bar'
    item_id INT UNSIGNED NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_favorites_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_favorite (user_id, item_type, item_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
