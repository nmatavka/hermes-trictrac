create schema if not exists sch1;

create table if not exists sch1."user"(
    id bigserial primary key,
    login text unique,
    username text not null,
    password text not null,
    invite_policy_code int not null default 0
);

create table if not exists sch1.friend_record(
    id bigserial primary key,
    first_user bigint not null references "user"(id),
    second_user bigint not null references "user"(id),
    created_at timestamp not null
);

create table if not exists sch1.friend_request(
    id bigserial primary key,
    "from" bigint not null references "user"(id),
    "to" bigint not null references "user"(id),
    created_at timestamp not null
);

-- start login test
insert into sch1."user"(id, login, username, password) values (9999, 'login test', 'roma', '123');
-- end login test

-- start create password test
insert into sch1."user"(id, login, username, password) values (1337, 'create password test', 'roma', '123');
-- end create password test

-- start delete user test
insert into sch1."user"(id, login, username, password) values (228, 'delete user test', 'roma', '123');
-- end delete user test

-- start update username test
insert into sch1."user"(id, login, username, password) values (1489, 'update username test', 'roma', '123');
-- end update username test

-- start create friend request test
insert into sch1."user"(id, login, username, password) values (301, 'create friend request test 1', 'roma', '123');
insert into sch1."user"(id, login, username, password) values (302, 'create friend request test 2', 'roma', '123');
-- end create friend request test

-- start create friend request test p2
insert into sch1."user"(id, login, username, password) values (309, 'create friend request test 3', 'roma', '123');
insert into sch1."user"(id, login, username, password) values (310, 'create friend request test 4', 'roma', '123');
-- end create friend request test p2

-- start add friend existed request test
insert into sch1."user"(id, login, username, password) values (303, 'add friend existed request 1', 'roma', '123');
insert into sch1."user"(id, login, username, password) values (304, 'add friend existed request 2', 'roma', '123');
insert into sch1.friend_request(id, "from", "to", created_at) values (304, 304, 303, '2025-01-26 14:30:00');
-- end add friend existed request test



-- start add friend already friend request
insert into sch1."user"(id, login, username, password) values (305, 'add friend already friend request 1', 'roma', '123');
insert into sch1."user"(id, login, username, password) values (306, 'add friend already friend request 2', 'roma', '123');
insert into sch1.friend_record(id, first_user, second_user, created_at) values (305, 305, 306, '2025-01-26 14:30:00');
-- end add friend already friend request


-- start add friend retry request
insert into sch1."user"(id, login, username, password) values (307, 'start add friend retry request 1', 'roma', '123');
insert into sch1."user"(id, login, username, password) values (308, 'start add friend retry request 2', 'roma', '123');
insert into sch1.friend_request(id, "from", "to", created_at) values (307, 308, 307, '2025-01-26 14:30:00');
-- end add friend retry request

-- start remove friend request
insert into sch1."user"(id, login, username, password) values (311, 'remove friend request 1', 'roma', '123');
insert into sch1."user"(id, login, username, password) values (312, 'remove friend request 2', 'roma', '123');
insert into sch1.friend_record(id, first_user, second_user, created_at) values (311, 311, 312, '2025-01-26 14:30:00');
-- end remove friend request

-- start get friends test
insert into sch1."user"(id, login, username, password) values (313, 'get friends test 1', 'john', '123');
insert into sch1."user"(id, login, username, password) values (314, 'get friends test 2', 'bob', '123');
insert into sch1."user"(id, login, username, password) values (315, 'get friends test 3', 'dave', '123');
insert into sch1.friend_record(id, first_user, second_user, created_at) values (313, 313, 314, '2025-01-26 14:30:00');
insert into sch1.friend_record(id, first_user, second_user, created_at) values (314, 313, 315, '2025-01-26 14:30:00');
-- end get friends test