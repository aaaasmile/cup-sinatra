== Database
Uso postgresql sotto  windows e pgAdmin4 v2.
Come riferimento dell'applicazione rails che creava gli utenti, mostrava le classifiche, si trova su:
D:\PC_Jim_2016\Projects\old_projects\RailsPlayground\LastRepositoryCopy\cupclassifica

Ho cominciato a creare il db:
db: cupuserdatadb
utente per il db: cup_user
pasword: vedi il file D:\scratch\sinatra\cup_sinatra_local\cup_srv\doc\readme.txt
host: localhost
port: 5432

Ho il backup in formato mysql, che è il file D:\PC_Jim_2016\Projects\host_europe_bck\sql\cuperativa_02_03_12.sql
con una sintassi che però non si può usare in postgresql. I dati messi in VALUES(xxx) invece si.
Per la struttura delle tabelle ho preferito usare lo script sql anziché usare la migration in ruby.

== Uso del gem pg per posgresql
Non avendo a disposizione ActiveRecord, bisogna usare il gem pg.
Si usa quindi il codice SQL direttamente e bisogna costruire manualmente lo statement
e poi dal risultato costruire l'oggetto.
Ho fatto un ORM molto primitivo cercando di scrivere solo il codice che mi serve.
In principio salvo in una lista i campi modificati da salvare. Riconosco anche se è un update
oppure un insert. ho avuto problemi con il time stamp che va modificato nello statement SQL,
in quanto uso: 2017-12-03 21:56:16, che in ruby si ha con strftime.
Ho un meta dei campi solo per quelli che non vanno bene usando to_s e li ho messi in @field_types.
Per evitare SQL injection uso dbpg_conn.escape_string.

== Websocket
Sono riuscito a fare andare il protocollo wss. Ho generato su Ubuntu il certificato
self signed con openssl. Due file .pem che ho messo nella sub dir ssl.
Il server secure funziona solo sotto linux. Però prima occorre aprire il browser
su di una pagina https per poter ignorare il warning che il certificato non è trusted.
Per fare questo ho usato rails sul progetto mysmilecv usando il server 'thin --ssl ...' e 
usando gli stessi files di certificato.  

== Sinatra e Log4net
Avevo il codice pieno di comandi come:
@log = Log4r::Logger.new("coregame_log::NalServerCoreBase")
ma non va. Sembra che ci sia un conflitto con lo standard Logger che 
viene usato da Sinatra. Infatti tenta di creare il Logger standard, invece di
Log4net. Il motivo è che quando sinatra comincia a fornire dei files, i logger sono 
automaticamente file logger senza std.out. Però l'assegnazione:
@log = Log4r::Logger["coregame_log"] 
funziona bene, sempre che sia abbia definito precedentemente il coregame_log nel file cuperativa_server.
Ho provato ad aggiungere rails5 come dipendenza (per usare Active record) e log4r non ha più funzionato,
come se la classe log4r fosse sparita. Quindi niente rails5, che poi è un polpettone enorme,
se uso sinatra è perché non voglio avere rails.
