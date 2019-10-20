== Info
Per partire vedere i setting che si trovano su ./bot_sample/robot.yaml
Siccome uso diversi target, ho creato due batch set_local e set_target per cambiare la
destinazione del robot.
Comandi:
$env:path = "D:\ruby\ruby_2_3_1\bin"
ruby cuperativa_bot.rb

== Info aggiuntive
Il robot si collega via websocket al server.
Questo avviene con il gem websocket-client-simple.
Siccome posso usare una sola WCL in windows, il robot lo faccio partire con una cmd.exe di windows
di ruby231 a 64 bit. 
Il comando da usare è, per i test, ruby cuperativa_bot.rb.
La url del server è ws://localhost:3000, vale a dire la stessa url di pezi lanciato in questa
directory.

== Websocket la soluzione
Dopo tanto provare con diverse versioni di ruby e librerire, ho constato che non
ne funziona nessuna in modo accettabile. Quelle basate su event machine non si 
connettono neanche.
Il simple webocket client (wsclient.rb) è quello che funziona di più, ma non
va il send e il parsing, quindi non si può usare.
La via invece che va è quella di aprire un socket tcp sul server e 
poi di mandare l'handshake. Per questo ho usato il gem websocket-ruby
(https://github.com/imanel/websocket-ruby). Nel file di test client_test.rb
c'è l'esempio molto promettente. Questo dovrebbe avere un minimo impatto sulla logica del
robot in quanto già prima apriva un socket. Basterebbe solo inserire l'handshake.

== Websocket send
Ho dovuto guardare la rfc https://datatracker.ietf.org/doc/rfc6455/?include_text=1
Per poi sapere che il client manda un payoload al server masked. La mascheratura e il calcolo
dei primi due bytes, li fa il gem websocket-ruby. Per il frame del client basta solo usare
la funzione corretta che è (nota il ::Client):
frame = WebSocket::Frame::Outgoing::Client.new(version: @handshake.version, data: "LOGIN:igor", type: :text)
@socket_srv.write frame.to_s
Se il frame non è corretto, per esempio perché si usa ::Server al posto di ::Cient, il server
chiude giustamente la connessione.

Altra particolarità del websocket è che bisogna usare 'write' per 
scrivere e 'getc' in lettura, altrimenti con 'puts' e 'gets' si hanno dei
problemi in trasmissione e dopo un paio di send la connessione finisce. Lo stesso
vale in lettura dove alcuni messaggi non sono corretti. 
