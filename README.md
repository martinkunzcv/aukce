# Interní aukční systém nad WeBid – Docker + Keycloak blueprint

> **Důležitá poznámka:** v zadaném repozitáři chyběl samotný upstream WeBid zdrojový kód. Tento commit proto dodává **kompletní deployment a implementační blueprint**, databázové rozšíření a dokumentaci, ale **nemůže ještě obsahovat finální patch konkrétních WeBid PHP souborů**, protože nejsou přítomné.

## 1. Zjištění při inspekci repozitáře

Při kontrole repozitáře byl přítomen pouze minimalistický `README.md`. To znamená:

- nešlo přímo zanalyzovat existující authentication flow ve WeBid,
- nešlo určit konkrétní názvy souborů/modelů pro users/bids/auctions/admin,
- nešlo bezpečně provést in-place patch jádra WeBid.

Podrobný rozbor a navržený souborový plán je v `docs/analysis-and-plan.md`.

## 2. Navržená cílová architektura

Služby v `docker-compose.yml`:

- `keycloak`
- `oauth2-proxy`
- `webid`
- `app-db` (MariaDB pro WeBid)
- `keycloak-db` (PostgreSQL pro Keycloak)
- persistentní Docker volumes pro všechny stateful komponenty

### Persistované části

- databáze WeBid: `app-db-data`
- databáze Keycloak: `keycloak-db-data`
- runtime data Keycloak: `keycloak-data`
- uploady/aplikační soubory WeBid: `webid-uploads`

Tím jsou data i konfigurace oddělena od lifecycle image/containerů.

## 3. Nejmenší bezpečný implementační přístup

1. **Vypnout veřejnou registraci a lokální login** v aplikaci.
2. **Autentizaci delegovat na Keycloak přes oauth2-proxy**.
3. **VeBidu důvěřovat jen předaným hlavičkám z trusted proxy**.
4. **Externí identitu mapovat na interního uživatele** pomocí `issuer + sub`, fallback podle e-mailu.
5. **Role mapovat z OIDC/Keycloak claimů** na:
   - `employee_bidder`
   - `auction_admin`
   - `auction_approver`
6. **Rozšířit lifecycle aukce** o explicitní stavy:
   - `draft`
   - `scheduled`
   - `running`
   - `ended_pending_approval`
   - `approved`
   - `cancelled`
7. **Po konci aukce vytvořit jen provizorní výsledek** a čekat na schválení.
8. **Identitu ostatních bidderů skrýt** všem kromě admin/approver rolí.
9. **Bid submission obalit transakcí** a zamykat řádky aukce.
10. **Auditovat login, změny aukce, bidy a approval/rejection**.

## 4. Dodané soubory

- `docker-compose.yml` – compose stack.
- `.env.example` – externí konfigurace přes env proměnné.
- `oauth2-proxy/oauth2-proxy.cfg.example` – ukázková konfigurace proxy.
- `db/migrations/001_internal_auction_extensions.sql` – SQL blueprint rozšíření schématu.
- `keycloak/README.md` – setup poznámky pro Keycloak + AD.
- `docs/analysis-and-plan.md` – inspekce, návrh a plán po souborech.
- `docker/webid/README.md` – instrukce pro override mount/custom image.
- `scripts/check-config.sh` – jednoduchá validační kontrola scaffoldu.

## 5. Jak to rozběhnout

### 5.1 Příprava

```bash
cp .env.example .env
# upravte hesla, client secret a hostname
```

Důležité nastavení v `.env`:
- `KEYCLOAK_EXTERNAL_URL` je URL, na které Keycloak otevíráte z browseru/hosta, typicky `http://localhost:8081`.
- `KEYCLOAK_INTERNAL_URL` je interní Docker adresa pro kontejnery, typicky `http://keycloak:8080`.
- `OAUTH2_PROXY_OIDC_ISSUER_URL` musí v Compose prostředí mířit na **interní** issuer URL, ne na `localhost`, jinak se `oauth2-proxy` pokouší připojit sám na sebe a spadne na `connection refused`.

### 5.2 Start stacku

```bash
docker compose up -d keycloak-db keycloak
```

Počkejte, až bude Keycloak healthy, a teprve potom spusťte zbytek stacku:

```bash
docker compose up -d
```

### 5.3 Keycloak konfigurace

Postup je v `keycloak/README.md`.

Minimum:
- realm `company-auctions` se při startu Keycloaku importuje automaticky ze souboru `keycloak/company-auctions-realm.json`,
- po prvním startu jen zkontrolovat, že byl import úspěšný,
- upravit client secret `webid` z placeholderu `replace-me` na reálnou hodnotu a zapsat stejnou hodnotu do `.env` jako `OAUTH2_PROXY_CLIENT_SECRET`,
- napojit AD přes LDAP/User Federation,
- podle potřeby upravit redirect URI / web origin,
- role `employee_bidder`, `auction_admin`, `auction_approver` jsou součástí importu,
- mapper pro realm roles do claimu `groups` je součástí importu.

### 5.4 Proč padal `oauth2-proxy`

Pokud jste v logu viděli chybu typu:
- `WARNING: mixing --trusted-ip with --reverse-proxy is a potential security vulnerability`
- `Get "http://localhost:8081/realms/company-auctions/.well-known/openid-configuration": connect: connection refused`

byly tam dva problémy:

1. `trusted_ips` v `oauth2-proxy` se nesmí kombinovat s `reverse_proxy`, pokud to není opravdu nezbytné. V této revizi je `trusted_ips` odstraněné a trust model se nechává na vnější proxy vrstvě a interní Docker síti.
2. `localhost:8081` je správná adresa z hostitelského stroje, ale **ne z kontejneru oauth2-proxy**. Uvnitř Compose musí issuer mířit na `http://keycloak:8080/realms/company-auctions`.
3. Pokud Keycloak vrací `404 {"error":"Realm does not exist"}`, chyběl import realmu. V této revizi je proto přidán `keycloak/company-auctions-realm.json`, který se při startu importuje přes `--import-realm`.
4. Keycloak healthcheck je teď zjednodušený na čistý TCP probe `: > /dev/tcp/127.0.0.1/8080`, aby neobsahoval žádné escapování ani HTTP request a byl co nejkompatibilnější s Docker Compose na Windows.


### 5.5 Troubleshooting: `password authentication failed for user "keycloak"`

Pokud Keycloak startuje, ale v logu je:
- `FATAL: password authentication failed for user "keycloak"`

je nejčastější příčina tato:

1. `keycloak-db` už byl jednou inicializovaný se starým heslem ve volume `keycloak-db-data`.
2. Vy jste potom změnil `KEYCLOAK_DB_PASSWORD` v `.env`, ale Postgres si původní heslo ve volume ponechal.

Důležité je, že `docker-compose.yml` používá **stejnou** proměnnou `KEYCLOAK_DB_PASSWORD` jak pro Postgres, tak pro Keycloak, takže pokud jde o čistý start bez starého volume, musí si rozumět.

Ověřte v `.env`:

```bash
KEYCLOAK_DB_USER=keycloak
KEYCLOAK_DB_PASSWORD=nejake_heslo
```

Pokud už jste stack spouštěl dřív a heslo měnil, smažte jen Keycloak DB volume a databázi nechte znovu inicializovat:

```bash
docker compose down
docker volume rm ${COMPOSE_PROJECT_NAME:-aukce}_keycloak-db-data
docker compose up -d keycloak-db keycloak
```

Pokud nechcete mazat volume, vraťte do `.env` původní heslo, se kterým byl Postgres volume poprvé vytvořen.

## 6. Co je ještě potřeba po doplnění upstream WeBid kódu

Jakmile se do repozitáře přidá reálný WeBid source tree, doporučené konkrétní změny jsou:

### Authentication flow
- odstranit veřejné login/register entrypointy z UI,
- přidat trusted-header bootstrap za `oauth2-proxy`,
- zakázat password reset pro běžné uživatele.

### User model
- rozšířit uživatele o externí identitu,
- zavést interní role mapované z Keycloak.

### Bid model
- transakční podání příhozu,
- bidder-only view ukazuje jen vlastní příhozy,
- current price + bid count zůstává viditelný.

### Auction lifecycle
- cron/expiry job změní `running -> ended_pending_approval`,
- approval screen provede `approved` nebo vrátí/odmítne výsledek.

### Admin area
- `auction_admin`: správa aukcí,
- `auction_approver`: schválení výsledků,
- audit log listing pouze pro privilegované role.

## 7. Bezpečnostní zásady

- WeBid musí důvěřovat auth hlavičkám **jen** z interní proxy vrstvy.
- `oauth2-proxy` i Keycloak mají běžet za interním reverse proxy / VPN.
- Pro produkci používejte TLS a ne `start-dev` režim Keycloak.
- Lokální účty ponechte pouze jako break-glass admin fallback, pokud to bude nezbytné; jinak je vypněte úplně.

## 8. Upgrade a persistence

### Upgrade image

1. zazálohujte volumes,
2. aktualizujte image tagy v compose,
3. spusťte migrace schématu,
4. proveďte `docker compose up -d`.

### Co přežije restart / update

Pokud zachováte Docker volumes, přežijí:
- aplikační databáze,
- Keycloak databáze a runtime data,
- uploady WeBid,
- konfigurační soubory v repozitáři.

## 9. Limit tohoto commitu

Protože repozitář neobsahoval upstream WeBid kód a síťový přístup k jeho stažení byl v tomto prostředí blokovaný, tento commit je **realistický a připravený scaffold**, ne finální aplikační fork WeBid. Jakmile bude zdrojový strom doplněn, lze podle `docs/analysis-and-plan.md` udělat konkrétní minimálně invazivní patch.
