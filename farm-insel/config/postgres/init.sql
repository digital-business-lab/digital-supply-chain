-- Initialisierung PostgreSQL für ChirpStack
-- Wird beim ersten Start ausgeführt

-- Erweiterung für UUID-Generierung
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Erweiterung für kryptografische Funktionen
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
