# Analýza repozitáře a plán

## Co je v repozitáři teď
V poskytnutém repozitáři se aktuálně nacházel pouze soubor `README.md` s jedním řádkem. Neobsahuje upstream WeBid zdrojový kód ani databázové schéma, takže nebylo možné provést doslovnou analýzu existující implementace autentizace, uživatelů, příhozů, stavového modelu aukcí ani administrace.

## Co by bylo potřeba analyzovat v reálném WeBid repozitáři
1. **Authentication flow**
   - entrypointy přihlášení/odhlášení,
   - session bootstrap,
   - lookup uživatele podle e-mailu/uživatelského jména,
   - veřejná registrace a password reset.
2. **User model**
   - tabulka `users`,
   - administrátorské příznaky/skupiny,
   - vazby na aukce a příhozy.
3. **Bid model**
   - tabulka `bids`,
   - zápis příhozu, validace minima, incrementu a času,
   - způsob výpočtu aktuální ceny a vítěze.
4. **Auction lifecycle/state handling**
   - tabulka `auctions`,
   - cron/expiry mechanismus,
   - admin akce create/update/publish/close.
5. **Admin area structure**
   - separátní admin front controller,
   - reusable authz guardy,
   - místo pro approval workflow a audit log.

## Nejmenší bezpečný implementační přístup
1. **Nechat Keycloak jako jediného identity providera** a dát WeBid za `oauth2-proxy`.
2. **Ve WeBid přijímat pouze trusted proxy headers** z interní sítě/reverse proxy a vypnout veřejnou registraci i lokální login.
3. **Nepřepisovat celý auth subsystém**, ale přidat „external identity bootstrap“ vrstvu:
   - najít nebo vytvořit interního uživatele podle `issuer + sub` / fallback na e-mail,
   - mapovat role z `X-Forwarded-Groups`.
4. **Rozšířit aukce o explicitní stavový automat** místo přetížení stávajících boolean flagů.
5. **Po expiraci vypočítat pouze provizorní výsledek** a vyžadovat approval od role `auction_approver`.
6. **Skrýt identitu ostatních přihazujících** na všech bidder-facing stránkách a API/templating výstupech.
7. **Admin/approver pohled nechat detailní**, ale přikrýt ho RBAC guardem.
8. **Audit log přidat append-only tabulkou**, aby zásah do stávajících tabulek byl malý.
9. **Bid submission obalit transakcí** s row-level lockem na aukci a znovunačtením aktuální nejvyšší nabídky.

## Souborový plán po importu upstream WeBid
> Protože upstream kód v repozitáři chybí, je to plán/blueprint, ne přesný diff proti konkrétním souborům.

- `includes/auth*.php`: trusted proxy auth bootstrap, disable local login/registration.
- `includes/user*.php`: mapování externí identity na interního uživatele, role resolver.
- `includes/auction*.php`: stavový automat, approval workflow, finalizace aukce.
- `includes/bid*.php`: transakční a concurrency-safe podání příhozu.
- `templates/*.tpl`: bidder view bez identity jiných účastníků.
- `admin/*`: approver obrazovky, audit listing, role guardy.
- `cron/*.php`: expirace aukcí -> `ended_pending_approval`.
- `database/*.sql`: migrace z tohoto repozitáře doplnit na konkrétní upstream schema names.

## Co bylo v tomto commitu skutečně dodáno
- Docker Compose architektura pro WeBid + DB + Keycloak + oauth2-proxy.
- Environment šablona.
- Example config pro oauth2-proxy.
- SQL blueprint migrace pro interní-only rozšíření.
- README s deployment, upgrade a persistence instrukcemi.
- Poznámky pro Keycloak setup.
- Jednoduchý validační skript konfigurace.

## Riziko / blokátor
Bez skutečného WeBid zdrojového kódu v repozitáři nelze udělat ani ověřit aplikační změny uvnitř WeBid core. Po doplnění upstreamu lze tento blueprint převést do konkrétních patchů.
