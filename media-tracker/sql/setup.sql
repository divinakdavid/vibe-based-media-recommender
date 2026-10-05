-- setup.sql
-- Creates the media_tracker database and selects it. Safe to re-run.
-- Requires MySQL 8.0.16 or newer (older versions accept CHECK constraints but silently ignore them).

CREATE DATABASE IF NOT EXISTS media_tracker
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE media_tracker;
