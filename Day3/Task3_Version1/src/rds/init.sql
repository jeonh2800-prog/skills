CREATE TABLE apdev.user (
    id          VARCHAR(255) NOT NULL,
    username    VARCHAR(255) NOT NULL,
    email       VARCHAR(255) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_username (username)
);

CREATE TABLE apdev.product (
    id          VARCHAR(255) NOT NULL,
    name        VARCHAR(255) NOT NULL,
    price       FLOAT(8)     NOT NULL,
    image_path  VARCHAR(500) NOT NULL,
    PRIMARY KEY (id)
);

CREATE INDEX idx_user_email ON apdev.user(email);
CREATE INDEX idx_product_name ON apdev.product(name);
CREATE INDEX idx_product_price ON apdev.product(price);