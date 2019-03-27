CREATE TABLE tbl (uu_id UUID NOT NULL, vc VARCHAR(10), i INT);
INSERT INTO tbl (vc, i) VALUES ('test', 0) RETURNING uu_id;
INSERT INTO tbl (vc, i) VALUES ('test1', 1), ('test2', 2) RETURNING uu_id, vc;
