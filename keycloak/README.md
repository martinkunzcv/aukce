# Keycloak setup notes

## Realm
- Realm name: `company-auctions`
- Client ID: `webid`
- Access type: confidential
- Root URL: `http://localhost:8080`
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
