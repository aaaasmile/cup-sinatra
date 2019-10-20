== Start localhost development
Questa è un app molto semplice scritta in sinatra. In config.ru viene preso il middleware cup_backend.rb
Il quale esamina la request ed apre un websocket se è necessario. Altrimenti serve l'app sotto public.
Per far partire l'app si usa:
$env:path = "D:\ruby\ruby_2_3_1\bin"
(ma è meglio usare la console linux per via del deploy su heroku). 
Ora si lancia il comando su WCL:
bundle exec puma -p 3000
In Visual Code lancio script di ruby per provare diverse funzioni in modo isolato, usando la powershell.
In WCL invece, faccio partire sinatra.

== Ruby installazione
Su WLC l'ho installato usando rbenv.
igors@Laptop-Toni:~$ rbenv versions
  2.2.4
* 2.3.1 (set by /home/igors/.rbenv/version)
Si dovrebbe usare rbenv anche per il deployment


== Deploy con WCL 
Copia lo stato della repository cup_sinatra (senza .git) in cup_sinatra_heroku_deploy e
*****IMPORTANTE SENZA il file*********
Gemfile.lock
***************
Così riesco ad evitare le incongruenze tra lo sviluppo sotto windows e il deploy sotto linux.
Poi si fa un test se tutto è ok prima del deploy.

== Repositories
vedi il file D:\scratch\sinatra\cup_sinatra_local su Readme_cup_sinatra.txt

== Websocket
Il gem faye-websocket sembra funzionare sotto windows se uso una console di windows.

Con la console di Linux sotto windows, il websocket all'inizio non mi ha funzionato.
Perché? In WCL il server alla connessione manda una serie ping
che vanno risposti con i pong. Passano a windows la situazione è migliorata, ma il probema è rimasto. 
Ho avuto problema nel completare la partita tra due robots.
Il problema è stato l'handling del frame di tipo ping, che avevo fatto manuale.
Questo è sbagliato e va fatto usando il pattern frame.next e si risponde con un frame 
di tipo pong.
Il formato text o binary è irrilevante e uso text.  
Un'altra stranezza è che EventMachine::add_periodic_timer non mi ha funzionato
sia su heroku che in WCL, il timer non partiva. Allora ho usato un thread.

== Robot admin interface
Si trova sotto la dir middleware/robots.
Sul robot ho messo una interfaccia semplice per rimandare l'ultimo comando
e vedere lo stato del frame. Usa il file bot_admin_check.rb per vedere il risultato. 
Per fare partire un robots, vai nella dir middleware/robots, apri una console con ruby e lancia:
ruby cuperativa_bot.rb
Esso si collega al localhost oppure heroku a seconda della configuarazione robot.yaml della dir robot_sample.


 




