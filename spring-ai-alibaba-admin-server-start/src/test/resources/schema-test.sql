DROP TABLE IF EXISTS account;
CREATE TABLE account
(
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    account_id VARCHAR(64) NOT NULL,
    username VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    mobile VARCHAR(255),
    password VARCHAR(255) NOT NULL,
    nickname VARCHAR(255),
    icon VARCHAR(255),
    type VARCHAR(64) NOT NULL,
    status TINYINT NOT NULL DEFAULT 1,
    gmt_create DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    gmt_modified DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    gmt_last_login DATETIME,
    creator VARCHAR(64) NOT NULL,
    modifier VARCHAR(64) NOT NULL
);
CREATE UNIQUE INDEX uk_account_id ON account(account_id);
CREATE INDEX idx_account_username ON account(username);

DROP TABLE IF EXISTS workspace;
CREATE TABLE workspace
(
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    workspace_id VARCHAR(64) NOT NULL,
    account_id VARCHAR(64) NOT NULL,
    status TINYINT NOT NULL DEFAULT 1,
    name VARCHAR(255) NOT NULL,
    description VARCHAR(4096),
    config TEXT,
    gmt_create DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    gmt_modified DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    creator VARCHAR(64) NOT NULL,
    modifier VARCHAR(64) NOT NULL
);
CREATE UNIQUE INDEX uk_workspace_id ON workspace(workspace_id);
CREATE INDEX idx_workspace_account_id ON workspace(account_id);

DROP TABLE IF EXISTS api_key;
CREATE TABLE api_key
(
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    account_id VARCHAR(64) NOT NULL,
    api_key VARCHAR(512) NOT NULL,
    status TINYINT NOT NULL DEFAULT 1,
    description VARCHAR(4096),
    gmt_create DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    gmt_modified DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    creator VARCHAR(64) NOT NULL,
    modifier VARCHAR(64) NOT NULL
);
CREATE UNIQUE INDEX uk_api_key ON api_key(api_key);
CREATE INDEX idx_api_key_account_id ON api_key(account_id);
