create schema if not exists sch1;

create table if not exists sch1."user"
(
    id                 bigserial primary key,
    login              text unique,
    username           text not null,
    password           text not null,
    invite_policy_code int  not null default 0
);

create table if not exists sch1.friend_record
(
    id          bigserial primary key,
    first_user  bigint    not null references sch1."user" (id) on delete cascade,
    second_user bigint    not null references sch1."user" (id) on delete cascade,
    created_at  timestamp not null
);

create table if not exists sch1.friend_request
(
    id         bigserial primary key,
    "from"     bigint    not null references sch1."user" (id) on delete cascade,
    "to"       bigint    not null references sch1."user" (id) on delete cascade,
    created_at timestamp not null
);

CREATE TABLE if not exists sch1."user_rating"
(
    id                 BIGSERIAL PRIMARY KEY,
    user_id            BIGINT  NOT NULL UNIQUE,
    backgammon_default INTEGER NOT NULL,
    backgammon_blitz   INTEGER NOT NULL,
    narde_blitz        INTEGER NOT NULL,
    narde_default      INTEGER NOT NULL,
    number_of_games    INTEGER NOT NULL,
    CONSTRAINT fk_user_rating_user FOREIGN KEY (user_id) REFERENCES sch1."user" (id) ON DELETE CASCADE
);