# WeBid override mount point

Do tohoto adresáře patří override soubory pro custom image / bind mount nad upstream WeBid aplikací.

V tomto repozitáři chybí upstream WeBid zdrojový strom, proto zde zatím není konkrétní patch. Jakmile bude přidán, doporučený postup je:

1. vytvořit vlastní image z upstream WeBid,
2. do image zkopírovat jen minimální override soubory,
3. proměnnými prostředí řídit trusted proxy auth, disable local login a role mapping.
