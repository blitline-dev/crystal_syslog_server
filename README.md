Test:

 echo "<134>Jan 16 21:07:33 cedis-1 cedis[1072]: jj6GZ LCREATE list:0W19rxER7il4KtrCsDCOcQg" | socat - "tcp4-connect:127.0.0.1:6768"
 echo "<134>Feb 27 00:54:37 ip-10-61-214-99 docker_king[1129]:"  | socat - "tcp4-connect:127.0.0.1:6768"
 echo "101 <134>1 2017-01-16T21:08:43.287929Z cedis-1 cedis 1072 cedis jj6GZ GETINT int:7N5_Ot_unayZ07ASfqQvYgg"  | socat - "tcp4-connect:127.0.0.1:6768"
 echo "73 <134>1 2017-01-16T21:09:32Z cedis-1 cedis 1072 cedis Index out of bounds" | socat - "tcp4-connect:127.0.0.1:6768"
 echo "<134>Jan 16 21:13:32 cedis-1 cedis jj6GZ DECR int:1hbE8qxgL5ngpcWc3EdQ6nw 1" | socat - "tcp4-connect:127.0.0.1:6768"
 echo "<134>Feb 27 00:54:37 ip-10-61-214-99 docker_king[1129]:" | socat - "tcp4-connect:127.0.0.1:6768"
 echo "<134>1 2018-06-05T21:52:31.329Z lambda lambda 1 - - {\"body\" : \"foo\"}" | socat - "tcp4-connect:127.0.0.1:6768"
 echo '<164>2019-06-04T20:34:33.217Z lambda LambdaApp[1]:"status_board [04/Jun/2019:20:34:28 +0000] \"GET /nydus/queue?format=json HTTP/1.1\" 200 12008"' | socat - "tcp4-connect:127.0.0.1:6768"
