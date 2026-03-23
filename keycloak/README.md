# Keycloak setup notes

## Realm
- Realm name: `company-auctions`
- Realm import file: `keycloak/company-auctions-realm.json`
- Client ID: `webid`
- Access type: confidential
- Root URL: `http://localhost:8080`
- Browser/admin access to Keycloak: `http://localhost:8081`
- Internal container-to-container URL: `http://keycloak:8080`
- Valid redirect URIs:
  - `http://localhost:8080/oauth2/callback`
- Web origins:
  - `http://localhost:8080`

## Identity source
- Připojte Active Directory přes User Federation / LDAP.
- Povinně synchronizujte atributy:
  - `sAMAccountName` nebo `userPrincipalName` -> username
  - `mail` -> email
  - `displayName` -> full name

## Roles
Vytvořte realm roles:
- `employee_bidder`
- `auction_admin`
- `auction_approver`

Doporučené mapování:
- běžní zaměstnanci -> `employee_bidder`
- správci aukcí -> `auction_admin`
- schvalovatelé -> `auction_approver`

## Token / claims mapping
OAuth2 Proxy i downstream aplikace musí dostat:
- `sub`
- `preferred_username`
- `email`
- `name`
- realm roles do claimu `groups` nebo `roles`

Doporučení:
- přidejte mapper, který pošle realm roles do `groups`, aby je `oauth2-proxy` snadno forwardoval.

## Security notes
- Pro produkci nahraďte `start-dev` příkaz plným `start` režimem.
- Zapněte HTTPS nebo terminaci TLS před compose stackem.
- Omezte přístup do Keycloak admin konzole jen z admin sítě/VPN.
- Nepoužívejte `localhost` jako issuer URL uvnitř jiných kontejnerů; tam musí být použita interní service DNS adresa `keycloak`.

## Troubleshooting
- Pokud vidíte `password authentication failed for user "keycloak"`, bývá problém ve starém persistentním volume Postgresu.
- `POSTGRES_PASSWORD` se použije jen při **první inicializaci** databázového volume. Pozdější změna `KEYCLOAK_DB_PASSWORD` v `.env` sama heslo uvnitř existující DB nezmění.
- V takovém případě buď vraťte původní heslo, nebo smažte volume `keycloak-db-data` a nechte DB vytvořit znovu.

- Po importu změňte client secret z placeholderu `replace-me` na reálnou hodnotu a stejnou hodnotu nastavte do `.env` jako `OAUTH2_PROXY_CLIENT_SECRET`.
