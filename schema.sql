-- we don't know how to generate root <with-no-name> (class Root) :(

comment on database postgres is 'default administrative connection database';

create type enum_type_role as enum ('ETUDIANT', 'EMPLOYEUR', 'ADMINISTRATEUR');

alter type enum_type_role owner to postgres;

create type enum_statut_compte as enum ('ACTIF', 'BANNI', 'ARCHIVE');

alter type enum_statut_compte owner to postgres;

create type enum_statut_candidature as enum ('CANDIDATE', 'SELECTIONNE', 'VALIDE', 'REFUSE');

alter type enum_statut_candidature owner to postgres;

create type enum_categorie_candidat as enum ('TITULAIRE', 'REMPLACANT');

alter type enum_categorie_candidat owner to postgres;

create table utilisateur
(
    id_utilisateur          uuid               default uuid_generate_v4()          not null
        primary key,
    email                   varchar(255)                                           not null
        unique,
    mot_de_passe            varchar(255)                                           not null,
    date_creation           timestamp          default now()                       not null,
    date_derniere_connexion timestamp,
    role                    enum_type_role                                         not null,
    statut                  enum_statut_compte default 'ACTIF'::enum_statut_compte not null
);

alter table utilisateur
    owner to postgres;

create table etudiant
(
    id_etudiant    uuid default uuid_generate_v4() not null
        primary key,
    id_utilisateur uuid                            not null
        unique
        references utilisateur
            on delete cascade,
    nom            varchar(100)                    not null,
    prenom         varchar(100)                    not null,
    ecole          varchar(255)                    not null,
    niveau_etudes  varchar(50)                     not null,
    competences    text[],
    localisation   varchar(255)
);

alter table etudiant
    owner to postgres;

create table employeur
(
    id_employeur   uuid default uuid_generate_v4() not null
        primary key,
    id_utilisateur uuid                            not null
        unique
        references utilisateur
            on delete cascade,
    raison_sociale varchar(255)                    not null,
    siret          char(14)                        not null
        unique,
    secteur        varchar(100),
    nom_contact    varchar(255)                    not null,
    logo           text,
    description    text,
    note_moyenne   numeric(3, 2)
        constraint employeur_note_moyenne_check
            check ((note_moyenne >= (0)::numeric) AND (note_moyenne <= (5)::numeric))
);

alter table employeur
    owner to postgres;

create table administrateur
(
    id_admin       uuid    default uuid_generate_v4() not null
        primary key,
    id_utilisateur uuid                               not null
        unique
        references utilisateur
            on delete cascade,
    nom            varchar(100)                       not null,
    prenom         varchar(100)                       not null,
    niveau_acces   integer default 1                  not null
        constraint administrateur_niveau_acces_check
            check ((niveau_acces >= 1) AND (niveau_acces <= 3))
);

alter table administrateur
    owner to postgres;

create table creneau_disponible
(
    id_creneau         uuid    default uuid_generate_v4() not null
        primary key,
    id_etudiant        uuid                               not null
        references etudiant
            on delete cascade,
    date_jour          date                               not null,
    heure_debut        time                               not null,
    heure_fin          time                               not null,
    est_recurrent      boolean default false              not null,
    date_debut_periode date,
    date_fin_periode   date,
    constraint chk_heures
        check (heure_fin > heure_debut),
    constraint chk_periode
        check ((est_recurrent = false) OR
               ((est_recurrent = true) AND (date_debut_periode IS NOT NULL) AND (date_fin_periode IS NOT NULL) AND
                (date_fin_periode > date_debut_periode)))
);

alter table creneau_disponible
    owner to postgres;

create index idx_creneau_etudiant
    on creneau_disponible (id_etudiant);

create index idx_creneau_date
    on creneau_disponible (date_jour);

create index idx_creneau_heures
    on creneau_disponible (heure_debut, heure_fin);

create table mission
(
    id_mission           uuid default uuid_generate_v4() not null
        primary key,
    id_employeur         uuid                            not null
        references employeur
            on delete cascade,
    titre                varchar(255)                    not null,
    description          text,
    salaire_horaire      numeric(6, 2)
        constraint mission_salaire_horaire_check
            check (salaire_horaire >= (0)::numeric),
    competences_requises text[],
    localisation         varchar(255)
);

alter table mission
    owner to postgres;

create index idx_mission_employeur
    on mission (id_employeur);

create table slot_mission
(
    id_slot          uuid default uuid_generate_v4() not null
        primary key,
    id_mission       uuid                            not null
        references mission
            on delete cascade,
    date_heure_debut timestamp                       not null,
    date_heure_fin   timestamp                       not null,
    localisation     varchar(255),
    constraint chk_slot_heures
        check (date_heure_fin > date_heure_debut)
);

alter table slot_mission
    owner to postgres;

create index idx_slot_mission
    on slot_mission (id_mission);

create index idx_slot_dates
    on slot_mission (date_heure_debut, date_heure_fin);

create table evaluation
(
    id_eval      uuid      default uuid_generate_v4() not null
        primary key,
    id_mission   uuid                                 not null
        references mission
            on delete cascade,
    id_etudiant  uuid
                                                      references etudiant
                                                          on delete set null,
    id_employeur uuid
                                                      references employeur
                                                          on delete set null,
    note         integer                              not null
        constraint evaluation_note_check
            check ((note >= 1) AND (note <= 5)),
    commentaire  text,
    date         timestamp default now()              not null,
    constraint chk_evaluateur
        check (((id_etudiant IS NOT NULL) AND (id_employeur IS NULL)) OR
               ((id_etudiant IS NULL) AND (id_employeur IS NOT NULL)))
);

alter table evaluation
    owner to postgres;

create index idx_evaluation_mission
    on evaluation (id_mission);

create index idx_evaluation_etudiant
    on evaluation (id_etudiant);

create index idx_evaluation_employeur
    on evaluation (id_employeur);

create table candidature
(
    id_candidature     uuid                    default uuid_generate_v4()                   not null
        primary key,
    id_etudiant        uuid                                                                 not null
        references etudiant
            on delete cascade,
    id_slot            uuid                                                                 not null
        references slot_mission
            on delete cascade,
    statut_candidature enum_statut_candidature default 'CANDIDATE'::enum_statut_candidature not null,
    categorie          enum_categorie_candidat default 'TITULAIRE'::enum_categorie_candidat not null,
    rang_priorite      integer                 default 1                                    not null
        constraint candidature_rang_priorite_check
            check (rang_priorite >= 1),
    date_candidature   timestamp               default now()                                not null,
    constraint uq_candidature
        unique (id_etudiant, id_slot)
);

alter table candidature
    owner to postgres;

create index idx_candidature_etudiant
    on candidature (id_etudiant);

create index idx_candidature_slot
    on candidature (id_slot);

create table detail_remplacant
(
    id_detail           uuid        default uuid_generate_v4()              not null
        primary key,
    id_candidature      uuid                                                not null
        unique
        references candidature
            on delete cascade,
    date_confirmation   timestamp,
    date_limite_reponse timestamp                                           not null,
    statut_reponse      varchar(50) default 'EN_ATTENTE'::character varying not null
        constraint detail_remplacant_statut_reponse_check
            check ((statut_reponse)::text = ANY
                   ((ARRAY ['EN_ATTENTE'::character varying, 'CONFIRME'::character varying, 'EXPIRE'::character varying])::text[]))
);

alter table detail_remplacant
    owner to postgres;

create table notification
(
    id_notif       uuid      default uuid_generate_v4() not null
        primary key,
    id_candidature uuid                                 not null
        references candidature
            on delete cascade,
    id_etudiant    uuid                                 not null
        references etudiant
            on delete cascade,
    message        text                                 not null,
    date_envoi     timestamp default now()              not null,
    date_limite    timestamp
);

alter table notification
    owner to postgres;

create index idx_notification_etudiant
    on notification (id_etudiant);

create index idx_notification_candidature
    on notification (id_candidature);

create table audit_trail
(
    id_audit          uuid      default uuid_generate_v4() not null
        primary key,
    id_utilisateur    uuid
                                                           references utilisateur
                                                               on delete set null,
    table_concernee   varchar(100)                         not null,
    ancienne_valeur   text,
    nouvelle_valeur   text,
    date_modification timestamp default now()              not null
);

alter table audit_trail
    owner to postgres;

create index idx_audit_table
    on audit_trail (table_concernee);

create index idx_audit_date
    on audit_trail (date_modification);

create index idx_audit_utilisateur
    on audit_trail (id_utilisateur);

create view vue_missions_disponibles
            (id_mission, titre, salaire_horaire, id_slot, date_heure_debut, date_heure_fin, localisation) as
SELECT m.id_mission,
       m.titre,
       m.salaire_horaire,
       s.id_slot,
       s.date_heure_debut,
       s.date_heure_fin,
       s.localisation
FROM mission m
         JOIN slot_mission s ON m.id_mission = s.id_mission
WHERE s.date_heure_debut >= now();

alter table vue_missions_disponibles
    owner to postgres;

create view vue_remplacants_par_slot(id_slot, id_etudiant, nom, prenom, date_candidature, rang_priorite) as
SELECT c.id_slot,
       e.id_etudiant,
       e.nom,
       e.prenom,
       c.date_candidature,
       rank() OVER (PARTITION BY c.id_slot ORDER BY c.date_candidature) AS rang_priorite
FROM candidature c
         JOIN etudiant e ON c.id_etudiant = e.id_etudiant
WHERE c.statut_candidature = 'CANDIDATE'::enum_statut_candidature
  AND c.categorie = 'REMPLACANT'::enum_categorie_candidat;

alter table vue_remplacants_par_slot
    owner to postgres;

create function uuid_nil() returns uuid
    immutable
    strict
    parallel safe
    language c
as
$$
begin
-- missing source code
end;
$$;

alter function uuid_nil() owner to postgres;

create function uuid_ns_dns() returns uuid
    immutable
    strict
    parallel safe
    language c
as
$$
begin
-- missing source code
end;
$$;

alter function uuid_ns_dns() owner to postgres;

create function uuid_ns_url() returns uuid
    immutable
    strict
    parallel safe
    language c
as
$$
begin
-- missing source code
end;
$$;

alter function uuid_ns_url() owner to postgres;

create function uuid_ns_oid() returns uuid
    immutable
    strict
    parallel safe
    language c
as
$$
begin
-- missing source code
end;
$$;

alter function uuid_ns_oid() owner to postgres;

create function uuid_ns_x500() returns uuid
    immutable
    strict
    parallel safe
    language c
as
$$
begin
-- missing source code
end;
$$;

alter function uuid_ns_x500() owner to postgres;

create function uuid_generate_v1() returns uuid
    strict
    parallel safe
    language c
as
$$
begin
-- missing source code
end;
$$;

alter function uuid_generate_v1() owner to postgres;

create function uuid_generate_v1mc() returns uuid
    strict
    parallel safe
    language c
as
$$
begin
-- missing source code
end;
$$;

alter function uuid_generate_v1mc() owner to postgres;

create function uuid_generate_v3(namespace uuid, name text) returns uuid
    immutable
    strict
    parallel safe
    language c
as
$$
begin
-- missing source code
end;
$$;

alter function uuid_generate_v3(uuid, text) owner to postgres;

create function uuid_generate_v4() returns uuid
    strict
    parallel safe
    language c
as
$$
begin
-- missing source code
end;
$$;

alter function uuid_generate_v4() owner to postgres;

create function uuid_generate_v5(namespace uuid, name text) returns uuid
    immutable
    strict
    parallel safe
    language c
as
$$
begin
-- missing source code
end;
$$;

alter function uuid_generate_v5(uuid, text) owner to postgres;

create function fn_update_note_moyenne() returns trigger
    language plpgsql
as
$$
BEGIN
    -- On ne met à jour que si l'évaluation concerne un employeur
    IF NEW.id_employeur IS NOT NULL THEN
        UPDATE employeur
        SET note_moyenne = (
            SELECT AVG(note)::NUMERIC(3,2)
            FROM evaluation
            WHERE id_employeur = NEW.id_employeur
        )
        WHERE id_employeur = NEW.id_employeur;
    END IF;
    RETURN NEW;
END;
$$;

alter function fn_update_note_moyenne() owner to postgres;

create function fn_audit_candidature() returns trigger
    language plpgsql
as
$$
BEGIN
    INSERT INTO audit_trail (
        table_concernee,
        ancienne_valeur,
        nouvelle_valeur,
        date_modification
    )
    VALUES (
        'candidature',
        row_to_json(OLD)::TEXT,
        row_to_json(NEW)::TEXT,
        NOW()
    );
    RETURN NEW;
END;
$$;

alter function fn_audit_candidature() owner to postgres;

create function fn_activation_remplacant() returns trigger
    language plpgsql
as
$$
DECLARE
    id_prochain_etudiant UUID;
BEGIN
    -- Condition : Le titulaire se désiste
    IF OLD.categorie = 'TITULAIRE' AND NEW.statut_candidature = 'REFUSE' THEN

        -- 1. Trouver le remplaçant de rang 1 pour ce slot précis
        SELECT id_etudiant INTO id_prochain_etudiant
        FROM candidature
        WHERE id_slot = NEW.id_slot
          AND categorie = 'REMPLACANT'
          AND rang_priorite = 1
          AND statut_candidature = 'CANDIDATE'
        LIMIT 1;

        IF id_prochain_etudiant IS NOT NULL THEN
            -- 2. Passer le remplaçant en "SELECTIONNE"
            UPDATE candidature
            SET statut_candidature = 'SELECTIONNE'
            WHERE id_etudiant = id_prochain_etudiant AND id_slot = NEW.id_slot;

            -- 3. Créer le détail avec la deadline de 30 min
            INSERT INTO detail_remplacant (id_candidature, date_limite_reponse, statut_reponse)
            SELECT id_candidature, NOW() + INTERVAL '30 minutes', 'EN_ATTENTE'
            FROM candidature
            WHERE id_etudiant = id_prochain_etudiant AND id_slot = NEW.id_slot;

            -- 4. Générer la notification pour l'étudiant
            INSERT INTO notification (id_candidature, id_etudiant, message, date_limite)
            SELECT id_candidature, id_etudiant, 'Urgent ! Une place s''est libérée. Vous avez 30 min pour confirmer.', NOW() + INTERVAL '30 minutes'
            FROM candidature
            WHERE id_etudiant = id_prochain_etudiant AND id_slot = NEW.id_slot;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

alter function fn_activation_remplacant() owner to postgres;

create function fn_est_disponible(p_id_etudiant uuid, p_id_slot uuid) returns boolean
    language plpgsql
as
$$
DECLARE
    v_debut_slot TIMESTAMP;
    v_fin_slot TIMESTAMP;
    v_est_dispo BOOLEAN;
BEGIN
    -- 1. Récupérer les horaires exacts de la mission
    SELECT date_heure_debut, date_heure_fin INTO v_debut_slot, v_fin_slot
    FROM slot_mission
    WHERE id_slot = p_id_slot;

    -- 2. Vérifier si l'étudiant a un créneau qui englobe ces horaires
    SELECT EXISTS (
        SELECT 1
        FROM creneau_disponible c
        WHERE c.id_etudiant = p_id_etudiant
        AND (
            -- Soit c'est un créneau ponctuel (date exacte)
            (c.est_recurrent = FALSE AND c.date_jour = v_debut_slot::DATE)
            OR
            -- Soit c'est récurrent (même jour de la semaine ET dans la bonne période)
            -- EXTRACT(ISODOW...) permet de comparer "Lundi = Lundi" (1 à 7)
            (c.est_recurrent = TRUE
             AND EXTRACT(ISODOW FROM c.date_jour) = EXTRACT(ISODOW FROM v_debut_slot)
             AND v_debut_slot::DATE BETWEEN c.date_debut_periode AND c.date_fin_periode)
        )
        -- Enfin, on vérifie que les heures couvrent toute la mission (ex: dispo 8h-18h pour mission 10h-12h)
        AND c.heure_debut <= v_debut_slot::TIME
        AND c.heure_fin >= v_fin_slot::TIME
    ) INTO v_est_dispo;

    RETURN v_est_dispo;
END;
$$;

alter function fn_est_disponible(uuid, uuid) owner to postgres;

create function fn_matching(p_id_etudiant uuid)
    returns TABLE(id_mission uuid, titre character varying, salaire_horaire numeric, id_slot uuid, date_heure_debut timestamp without time zone, date_heure_fin timestamp without time zone, localisation character varying)
    language plpgsql
as
$$
BEGIN
    RETURN QUERY
    SELECT
        m.id_mission,
        m.titre,
        m.salaire_horaire,
        s.id_slot,
        s.date_heure_debut,
        s.date_heure_fin,
        s.localisation
    FROM mission m
    JOIN slot_mission s ON m.id_mission = s.id_mission
    JOIN etudiant e ON e.id_etudiant = p_id_etudiant
    WHERE
        -- 1. La mission est dans le futur
        s.date_heure_debut > NOW()

        -- 2. Matching des compétences :
        -- Soit la mission ne demande rien (NULL ou vide), soit les tableaux s'intersectent (&&)
        AND (
            m.competences_requises IS NULL
            OR m.competences_requises = '{}'
            OR m.competences_requises && e.competences
        )

        -- 3. Appel à notre fonction de disponibilité
        AND fn_est_disponible(p_id_etudiant, s.id_slot) = TRUE

        -- 4. Exclure les slots auxquels l'étudiant a DÉJÀ postulé
        AND NOT EXISTS (
            SELECT 1 FROM candidature c
            WHERE c.id_etudiant = p_id_etudiant AND c.id_slot = s.id_slot
        );
END;
$$;

alter function fn_matching(uuid) owner to postgres;

create function fn_expiration_remplacant() returns trigger
    language plpgsql
as
$$
DECLARE
    id_prochain_etudiant UUID;
    id_candidature_expiree UUID;
BEGIN
    -- On vérifie si la deadline est dépassée et le statut toujours EN_ATTENTE
    IF NEW.statut_reponse = 'EN_ATTENTE' AND NOW() > NEW.date_limite_reponse THEN

        -- 1. Passer ce remplaçant à EXPIRE
        UPDATE detail_remplacant
        SET statut_reponse = 'EXPIRE'
        WHERE id_candidature = NEW.id_candidature;

        -- 2. Passer la candidature à REFUSE
        UPDATE candidature
        SET statut_candidature = 'REFUSE'
        WHERE id_candidature = NEW.id_candidature
        RETURNING id_candidature INTO id_candidature_expiree;

        -- 3. Chercher le prochain remplaçant disponible sur ce slot
        SELECT c.id_etudiant INTO id_prochain_etudiant
        FROM candidature c
        JOIN candidature c_expire ON c_expire.id_candidature = id_candidature_expiree
        WHERE c.id_slot = c_expire.id_slot
          AND c.categorie = 'REMPLACANT'
          AND c.statut_candidature = 'CANDIDATE'
        ORDER BY c.rang_priorite ASC
        LIMIT 1;

        IF id_prochain_etudiant IS NOT NULL THEN
            -- 4. Activer le prochain remplaçant
            UPDATE candidature
            SET statut_candidature = 'SELECTIONNE'
            WHERE id_etudiant = id_prochain_etudiant
              AND id_slot = (
                SELECT id_slot FROM candidature
                WHERE id_candidature = id_candidature_expiree
              );

            -- 5. Créer un nouveau detail_remplacant avec 30 min
            INSERT INTO detail_remplacant (id_candidature, date_limite_reponse, statut_reponse)
            SELECT id_candidature, NOW() + INTERVAL '30 minutes', 'EN_ATTENTE'
            FROM candidature
            WHERE id_etudiant = id_prochain_etudiant
              AND id_slot = (
                SELECT id_slot FROM candidature
                WHERE id_candidature = id_candidature_expiree
              );

            -- 6. Notifier le prochain remplaçant
            INSERT INTO notification (id_candidature, id_etudiant, message, date_limite)
            SELECT id_candidature, id_etudiant,
                   'Urgent ! Le remplaçant précédent n''a pas répondu. Vous avez 30 min pour confirmer.',
                   NOW() + INTERVAL '30 minutes'
            FROM candidature
            WHERE id_etudiant = id_prochain_etudiant
              AND id_slot = (
                SELECT id_slot FROM candidature
                WHERE id_candidature = id_candidature_expiree
              );
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

alter function fn_expiration_remplacant() owner to postgres;

