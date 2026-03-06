1 open 2,2,0,chr$(8)+chr$(0)
9 poke 53280,0:poke 53281,0:print chr$(147);:gosub 2700
10 print chr$(147);chr$(5);
11 print "  ham commander v2.0"
12 print chr$(159);"  loading..."
15 sv$="127.0.0.1":pt$="6400"
16 mc$="n0call":bd$="1200"
17 mn$="":mg$=""
18 ol=0:sc=0:rc=0:li$="0":pq=0:sp=0:lp=0:sl=0:fi=0
19 fb$="":fm$=""
28 ut$="00000000":uh$="0000"
29 s9$="                                                                                   "
31 dim ca$(20),fq$(20),mo$(20),rf$(20),sd$(20)
35 dim xc$(20),xb$(20),xd$(20),xr$(20)
40 dim fx(20)
42 h$="---------------------------------------"
43 e$="======================================="
44 da$="hamlog.dat,l,"+chr$(168)
45 su$="hamlog.sum,l,"+chr$(40)
50 gosub 2400
52 gosub 2450
54 gosub 2480
55 print " station: ";mc$
56 if mn$<>"" then print " op name: ";mn$
57 if mg$<>"" then print "    grid: ";mg$
58 print "  server: ";sv$;":";pt$
59 print " records: ";rc
60 if pq>0 then print " pending: ";pq
61 print
62 print " enter utc date (yyyymmdd):"
63 input " [enter=skip] ";td$
64 if td$<>"" then ut$=td$
65 if td$<>"" then print " enter utc time (hhmm):"
66 if td$<>"" then input " ";th$:uh$=th$
67 print
68 print " press any key..."
69 get w$:if w$="" then 69
72 lp=0:sc=0:gosub 500
102 get k$:if k$="" then 102
104 if k$=chr$(133) and ol=1 then sc=1:gosub 1300:goto 102
105 if k$=chr$(133) and ol=0 then sc=1:gosub 200:goto 102
106 if k$=chr$(134) then sc=0:lp=0:gosub 500:goto 102
108 if k$=chr$(135) then sc=2:gosub 1000:goto 102
110 if k$=chr$(136) and ol=0 then goto 1500
111 if k$=chr$(136) and ol=1 then goto 1700
114 if k$=chr$(17) then gosub 150:goto 102
116 if k$=chr$(145) then gosub 160:goto 102
118 if k$=chr$(13) then gosub 170:goto 102
120 if k$=chr$(20) then gosub 180:goto 102
122 if k$=chr$(137) and sc=1 then gosub 1300:goto 102
124 if k$=chr$(139) and ol=1 then goto 1750
126 if k$=chr$(138) then gosub 2600:goto 102
128 if k$="d" and sc=3 then gosub 843:goto 102
129 goto 102
150 if sc=0 then gosub 561:return
151 if sc=1 then gosub 260:return
152 return
160 if sc=0 then gosub 571:return
161 if sc=1 then gosub 270:return
162 return
170 if sc=0 then gosub 580:return
171 if sc=1 then gosub 280:return
172 return
180 if sc=3 then sc=0:gosub 500:return
181 return
200 if ol=0 then gosub 2200
203 if ol=0 then print:print "  go online for spots (f7)"
204 if ol=0 then gosub 2260:return
206 gosub 2200
207 print " fetching spots..."
208 cm$="spots"
209 if fb$<>"" then cm$=cm$+","+fb$
210 if fm$<>"" then cm$=cm$+","+fm$
211 gosub 2000
212 gosub 2010
214 if left$(rl$,6)<>"!spots" then 231
215 sp=val(mid$(rl$,8)):if sp>20 then sp=20
216 if sp<1 then print " no spots.":gosub 2260:return
217 print " loading ";sp;" spots...";
218 for i=1 to sp
219 gosub 2010
220 gosub 240
221 if i<1 or i>20 then 225
222 ca$(i)=p1$:fq$(i)=p2$:mo$(i)=p3$
223 rf$(i)=p4$
224 sd$(i)=p5$+"|"+p6$+"|"+p7$
225 next i
227 gosub 2010
229 gosub 290
231 sl=0:gosub 300
232 return
240 p1$="":p2$="":p3$="":p4$="":p5$="":p6$="":p7$=""
241 tl$=rl$:pn=1
242 for j=1 to len(tl$)
243 c$=mid$(tl$,j,1)
244 if c$<>"," then 248
245 pn=pn+1:if pn>7 then j=len(tl$):goto 249
246 goto 249
248 on pn goto 251,252,253,254,255,256,257
249 next j:return
251 p1$=p1$+c$:goto 249
252 p2$=p2$+c$:goto 249
253 p3$=p3$+c$:goto 249
254 p4$=p4$+c$:goto 249
255 p5$=p5$+c$:goto 249
256 p6$=p6$+c$:goto 249
257 p7$=p7$+c$:goto 249
260 mx=fi-1:if mx<0 then mx=0
261 if sl<mx then sl=sl+1:gosub 300
262 return
270 if sl>0 then sl=sl-1:gosub 300
271 return
280 if fi=0 then return
281 ix=fx(sl+1)
283 nc$=ca$(ix):nf$=fq$(ix):nm$=mo$(ix)
284 nb$=""
285 gosub 1280
286 sc=2:gosub 1000
287 return
290 fi=0
291 for i=1 to sp
292 fi=fi+1:fx(fi)=i
293 next i
294 return
300 gosub 2200
302 st$=""
303 if ol=1 then st$="online"
304 if ol=0 then st$="offline"
305 if fb$<>"" or fm$<>"" then st$=st$+" | "+fb$+" "+fm$
306 st$=st$+" | "+str$(fi)+" spots"
307 print chr$(159);left$(st$,40);chr$(5)
309 print chr$(154);h$;chr$(5)
311 vw=19
312 tp=sl:if tp>fi-vw then tp=fi-vw
313 if tp<0 then tp=0
315 for i=0 to vw-1
316 ri=tp+i+1
317 if ri>fi then print "                                        ";:goto 330
318 ix=fx(ri)
320 if tp+i=sl then print chr$(158);chr$(18);
321 cl$=left$(ca$(ix)+"          ",10)
322 fr$=left$(fq$(ix)+"       ",7)
323 md$=left$(mo$(ix)+"    ",4)
324 pr$=left$(rf$(ix)+"          ",10)
325 print cl$;fr$;" ";md$;" ";pr$;
326 if tp+i=sl then print chr$(146);chr$(5);
327 print
330 next i
332 print chr$(154);h$;chr$(5)
333 print chr$(155);" enter=log  f2=filter  ";chr$(17);chr$(145);"=scroll";chr$(5)
334 gosub 2260
335 return
500 gosub 2200
504 st$=""
505 if ol=1 then st$="online"
506 if ol=0 then st$="offline"
507 st$=st$+" | "+str$(rc)+" qsos"
508 if pq>0 then st$=st$+" | pend:"+str$(pq)
509 print left$(st$,40)
510 print chr$(154);h$;chr$(5)
512 if rc=0 then print:print "  no qsos yet. press f5 to add.":gosub 2260:sl=0:return
513 gosub 1900
515 sl=0:vw=19
516 gosub 540
517 return
540 gosub 2200:gosub 2220
542 pg=lp*19
544 pc=19:if pg+pc>rc then pc=rc-pg
545 if pc<0 then pc=0
546 for i=0 to vw-1
547 if i>=pc then print:goto 555
548 if i=sl then print chr$(158);chr$(18);
550 gosub 590
551 print ln$;
552 if i=sl then print chr$(146);chr$(5);
553 print
555 next i
556 print chr$(154);h$;chr$(5)
557 print chr$(155);" pg ";lp+1;" enter=detail ";chr$(17);chr$(145);"=scroll";chr$(5)
558 gosub 2260
559 return
561 pg=lp*19:pc=19:if pg+pc>rc then pc=rc-pg
562 if pc<1 then return
563 if sl<pc-1 then os=sl:sl=sl+1:gosub 600:return
565 if (lp+1)*19<rc then lp=lp+1:gosub 1900:sl=0:gosub 540
566 return
571 if sl>0 then os=sl:sl=sl-1:gosub 600:return
573 if lp>0 then lp=lp-1:gosub 1900:sl=18:gosub 540
574 return
580 if rc=0 then return
581 rn=rc-lp*19-sl
582 if rn<1 then return
583 sc=3:gosub 800
584 return
590 d$=left$(xd$(i+1),8)
592 if len(xd$(i+1))>9 then t$=mid$(xd$(i+1),10,4):goto 594
593 t$="----"
594 cl$=left$(xc$(i+1)+"         ",9)
595 bx$=left$(xb$(i+1),3)
596 md$=left$(mid$(xb$(i+1),6,3)+"   ",3)
598 ln$=mid$(d$,5,2)+"/"+mid$(d$,7,2)+"/"+mid$(d$,3,2)+" "+t$+" "+cl$+bx$+" "+md$
599 return
600 i=os:gosub 590:poke 214,os+1:print
604 print left$(ln$+"                                        ",39);
605 i=sl:gosub 590:poke 214,sl+1:print
606 print chr$(158);chr$(18);left$(ln$+"                                        ",39);chr$(146);chr$(5);
607 return
800 gosub 2200
803 print "  loading detail..."
805 rn=rc-lp*19-sl
806 open 15,8,15
807 open 3,8,3,da$
808 lo=rn and 255:hi=int(rn/256)
809 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
810 input#3,a$:print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(85)
811 input#3,b$:if len(b$)<83 then b$=left$(s9$,83-len(b$))+b$
812 close 3:close 15:w$=a$+b$
814 gosub 2200:print "  qso detail"
817 print chr$(154);h$;chr$(5)
818 print
819 print "  call: ";left$(w$,12)
820 print "  band: ";mid$(w$,13,6)
821 print "  mode: ";mid$(w$,19,6)
822 print "  freq: ";mid$(w$,37,10)
823 print "  date: ";mid$(w$,25,8)
824 print "  time: ";mid$(w$,33,4);" utc"
825 print "  sent: ";mid$(w$,47,3)
826 print "  rcvd: ";mid$(w$,50,3)
827 g$=mid$(w$,118,6):if g$<>"      " then print "  grid: ";g$
828 n$=mid$(w$,124,30):if left$(n$,1)<>" " then print "  name: ";n$
829 c$=mid$(w$,154,14):if left$(c$,1)<>" " then print "  ctry: ";c$
830 co$=mid$(w$,78,40):if left$(co$,1)<>" " then print "  note: ";left$(co$,30)
831 print
832 lg$=mid$(w$,65,12):if left$(lg$,1)<>" " then print "  logid: ";lg$
833 sf$=mid$(w$,77,1)
834 if sf$="s" then print "  status: synced"
835 if sf$="p" then print "  status: pending sync"
836 if sf$="n" then print "  status: local only"
837 print chr$(154);h$;chr$(5)
838 print chr$(155);" del=back  d=delete qso";chr$(5)
839 gosub 2260
840 return
843 print chr$(147);chr$(5);
844 print "  delete this qso?"
845 print "  ";xc$(sl+1);" ";left$(xd$(sl+1),8)
846 print
847 print "  y=delete  n=cancel"
848 get w$:if w$="" then 848
849 if w$<>"y" then sc=3:gosub 800:return
851 rn=rc-lp*19-sl:gosub 890:return
890 open 15,8,15
891 open 3,8,3,da$
892 lo=rn and 255:hi=int(rn/256)
893 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
894 input#3,a$:print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(85)
895 input#3,b$:if len(b$)<83 then b$=left$(s9$,83-len(b$))+b$
896 w$=a$+b$:w$=left$(w$,76)+"d"+mid$(w$,78)
897 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
898 print#3,left$(w$,83):print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(85):print#3,mid$(w$,84)
899 close 3:open 3,8,3,su$
900 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
901 input#3,w$:w$=left$(w$,36)+"d"+mid$(w$,38):print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1):print#3,w$
902 close 3:close 15
903 print "  qso deleted."
904 for w=1 to 500:next w
905 sc=0:gosub 500:return
1000 gosub 2200
1003 print "  new qso entry"
1004 print chr$(154);h$;chr$(5)
1007 if nc$="" then print:input "  callsign: ";nc$
1008 if nc$<>"" then print "  callsign: ";nc$
1009 if nc$="" then sc=0:gosub 500:return
1012 lk$="":lg$="":ln$="":ly$=""
1013 if ol=1 then gosub 1200
1015 if nb$="" then input "      band: ";nb$
1016 if nb$<>"" then print "      band: ";nb$
1017 if nm$="" then input "      mode: ";nm$
1018 if nm$<>"" then print "      mode: ";nm$
1019 if nf$="" then input "  freq khz: ";nf$
1020 if nf$<>"" then print "  freq khz: ";nf$
1021 print
1023 nd$=ut$:nt$=uh$
1024 print "  date [";nd$;"]: ";
1025 input "";td$
1026 if td$<>"" then nd$=td$
1027 print "  time [";nt$;"]: ";
1028 input "";tt$
1029 if tt$<>"" then nt$=tt$
1031 rs$="599":rr$="599"
1032 input "  rst sent [599]: ";tr$
1033 if tr$<>"" then rs$=tr$
1034 input "  rst rcvd [599]: ";tr$
1035 if tr$<>"" then rr$=tr$
1037 co$=""
1038 input "  comment: ";co$
1040 na$=ln$:gr$=lg$:cy$=ly$
1041 if gr$="" then gr$=mg$
1043 print:print chr$(154);h$;chr$(5)
1044 print "  ";nc$;" ";nb$;" ";nm$
1045 print "  ";nd$;" ";nt$;" utc"
1046 print "  rst: ";rs$;" / ";rr$
1047 if na$<>"" then print "  name: ";na$
1048 if co$<>"" then print "  note: ";left$(co$,30)
1049 print chr$(154);h$;chr$(5)
1050 print "  y=save  n=cancel"
1051 get w$:if w$="" then 1051
1052 if w$<>"y" then nc$="":nf$="":nm$="":nb$="":sc=0:gosub 500:return
1055 rc=rc+1
1056 gosub 1100
1057 gosub 1130
1058 gosub 1150
1059 pq=pq+1
1061 gosub 2460
1063 print:print "  qso saved! #";rc
1064 if pq>0 and ol=0 then print "  pending sync: ";pq
1066 if ol=1 then gosub 1170
1067 for w=1 to 1000:next w
1069 nc$="":nf$="":nm$="":nb$=""
1070 sc=0:gosub 500
1071 return
1100 w$=left$(nc$+"            ",12)
1102 w$=w$+left$(nb$+"      ",6)
1103 w$=w$+left$(nm$+"      ",6)
1104 w$=w$+left$(nd$+"        ",8)
1105 w$=w$+left$(nt$+"    ",4)
1106 w$=w$+left$(nf$+"          ",10)
1107 w$=w$+left$(rs$+"   ",3)
1108 w$=w$+left$(rr$+"   ",3)
1109 w$=w$+left$(mc$+"            ",12)
1110 w$=w$+left$("            ",12)
1111 w$=w$+"n"
1112 w$=w$+left$(co$+"                                        ",40)
1113 w$=w$+left$(gr$+"      ",6)
1114 w$=w$+left$(na$+"                              ",30)
1115 w$=w$+left$(cy$+"             ",13)
1117 open 15,8,15
1118 open 3,8,3,da$
1120 lo=rc and 255:hi=int(rc/256)
1121 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
1122 print#3,left$(w$,83):print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(85):print#3,mid$(w$,84)
1124 input#15,en,em$,et$,es$:close 3:close 15
1125 if en>0 then print chr$(18);" disk error: ";em$;" ";chr$(146):rc=rc-1
1126 return
1130 s$=left$(nc$+"          ",10)+left$(nb$+"    ",4)+left$(nm$+"    ",4)
1131 s$=s$+left$(nd$+"        ",8)+left$(nt$+"    ",4)+left$(rs$+"   ",3)+left$(rr$+"   ",3)+"n  "
1132 open 15,8,15
1133 open 3,8,3,su$
1134 lo=rc and 255:hi=int(rc/256)
1135 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
1136 print#3,s$
1137 close 3:close 15
1138 return
1150 open 4,8,4,"hamlog.que,s,a"
1152 print#4,nc$;",";nb$;",";nm$;",";nf$;",";nd$;",";nt$;",";rs$;",";rr$;",";co$;",";rc
1153 close 4
1154 return
1170 cm$="add,"+nc$+","+nb$+","+nm$+","+nf$+","+nd$+","+nt$+","+rs$+","+rr$+","+co$
1171 gosub 2000
1172 gosub 2010
1173 if left$(rl$,7)="!add,ok" then gosub 1180:return
1174 print "  upload failed - queued"
1175 return
1180 lg$=mid$(rl$,9)
1183 open 15,8,15
1184 open 3,8,3,da$
1185 lo=rc and 255:hi=int(rc/256)
1186 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
1187 input#3,a$:print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(85)
1188 input#3,b$:if len(b$)<83 then b$=left$(s9$,83-len(b$))+b$
1189 w$=a$+b$:w$=left$(w$,64)+left$(lg$+"            ",12)+"s"+mid$(w$,78)
1190 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
1191 print#3,left$(w$,83):print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(85):print#3,mid$(w$,84)
1192 close 3:open 3,8,3,su$:print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
1193 input#3,s$:s$=left$(s$,36)+"s"+mid$(s$,38):print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1):print#3,s$:close 3:close 15
1194 pq=pq-1:if pq<0 then pq=0
1195 print "  synced! logid: ";lg$
1196 return
1200 print "  looking up ";nc$;"..."
1201 cm$="lookup,"+nc$
1202 gosub 2000
1203 gosub 2010
1204 if left$(rl$,10)<>"!lookup,ok" then print "  not found":return
1205 gosub 2010
1207 gosub 240
1208 ln$=p2$
1209 lg$=p7$
1211 ly$=p6$
1212 if ln$<>"" then print "  name: ";ln$
1213 if lg$<>"" then print "  grid: ";lg$
1214 gosub 2010
1215 return
1280 fv=val(nf$)
1281 nb$=""
1282 if fv>=1800 and fv<=2000 then nb$="160m":return
1283 if fv>=3500 and fv<=4000 then nb$="80m":return
1284 if fv>=7000 and fv<=7300 then nb$="40m":return
1285 if fv>=10100 and fv<=10150 then nb$="30m":return
1286 if fv>=14000 and fv<=14350 then nb$="20m":return
1287 if fv>=18068 and fv<=18168 then nb$="17m":return
1288 if fv>=21000 and fv<=21450 then nb$="15m":return
1289 if fv>=24890 and fv<=24990 then nb$="12m":return
1290 if fv>=28000 and fv<=29700 then nb$="10m":return
1291 if fv>=50000 and fv<=54000 then nb$="6m":return
1292 if fv>=144000 and fv<=148000 then nb$="2m":return
1293 return
1300 print chr$(147);chr$(5);
1303 print chr$(154);e$;chr$(5);
1304 print "         spot filter"
1305 print chr$(154);e$;chr$(5);
1306 print
1307 print "  band:"
1308 print "  0=all 1=160 2=80 3=40 4=20"
1309 print "  5=17  6=15  7=12 8=10 9=6m"
1310 print
1311 print "  select band: ";
1312 get w$:if w$="" then 1312
1313 print w$
1314 fb$=""
1315 if w$="1" then fb$="160m"
1316 if w$="2" then fb$="80m"
1317 if w$="3" then fb$="40m"
1318 if w$="4" then fb$="20m"
1319 if w$="5" then fb$="17m"
1320 if w$="6" then fb$="15m"
1321 if w$="7" then fb$="12m"
1322 if w$="8" then fb$="10m"
1323 if w$="9" then fb$="6m"
1324 print
1325 print "  mode:"
1326 print "  0=all 1=cw 2=ssb 3=ft8 4=fm"
1327 print
1328 print "  select mode: ";
1329 get w$:if w$="" then 1329
1330 print w$
1331 fm$=""
1332 if w$="1" then fm$="cw"
1333 if w$="2" then fm$="ssb"
1334 if w$="3" then fm$="ft8"
1335 if w$="4" then fm$="fm"
1336 print
1337 if fb$="" and fm$="" then print "  filter: all"
1338 if fb$<>"" or fm$<>"" then print "  filter: ";fb$;" ";fm$
1339 print
1340 print chr$(155);"  enter=apply  del=clear";chr$(5)
1341 get w$:if w$="" then 1341
1342 if w$=chr$(20) then fb$="":fm$=""
1344 sc=1:gosub 200
1345 return
1500 gosub 2200
1503 print "  going online..."
1504 print chr$(154);h$;chr$(5)
1506 print " connecting..."
1510 print " dialing ";sv$;":";pt$
1511 print#2,"atdt"+sv$+":"+pt$+chr$(13);
1512 print " connecting";
1513 cf=0:for w=1 to 2000
1514 get#2,a$
1515 if a$="" or a$=chr$(0) then 1518
1516 if a$=chr$(13) and cf=1 then print:w=2000
1517 if a$>=chr$(32) and a$<chr$(127) then print a$;:cf=1
1518 next w
1519 print
1521 cm$="hello":gosub 2000
1522 gosub 2010
1523 goto 1524
1524 if left$(rl$,3)<>"!ok" then print " connection failed":goto 1540
1526 gosub 240
1529 ut$=p4$:uh$=p5$
1530 ol=1
1531 print " online! utc: ";ut$;" ";uh$
1532 print
1533 if pq>0 then print " ";pq;" qsos pending sync (f6)"
1534 print
1535 print " press any key..."
1536 get w$:if w$="" then 1536
1537 if sc=1 then gosub 200:goto 102
1538 sc=0:gosub 500:goto 102
1540 ol=0
1541 print " press any key..."
1542 get w$:if w$="" then 1542
1543 if sc=1 then gosub 200:goto 102
1544 sc=0:gosub 500:goto 102
1550 print " uploading ";pq;" pending qsos..."
1551 open 4,8,4,"hamlog.que,s,r"
1552 uq=0
1554 if st and 64 then 1580
1555 input#4,qc$,qb$,qm$,qf$,qd$,qt$,qs$,qr$,qo$,qn$
1556 if st and 64 then 1580
1558 cm$="add,"+qc$+","+qb$+","+qm$+","+qf$+","+qd$+","+qt$+","+qs$+","+qr$+","+qo$
1559 gosub 2000:gosub 2010
1560 if left$(rl$,7)="!add,ok" then uq=uq+1:print " synced: ";qc$
1561 if left$(rl$,7)<>"!add,ok" then print " failed: ";qc$
1563 rn=val(qn$):if rn>0 and left$(rl$,7)="!add,ok" then gosub 1590
1564 goto 1554
1580 close 4
1581 pq=pq-uq:if pq<0 then pq=0
1582 print " uploaded: ";uq;" qsos"
1584 if pq=0 then open 15,8,15,"s0:hamlog.que":close 15
1585 gosub 2460
1586 return
1590 lg$=mid$(rl$,9)
1591 open 15,8,15
1592 open 3,8,3,da$
1593 lo=rn and 255:hi=int(rn/256)
1594 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
1595 input#3,a$:print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(85)
1596 input#3,b$:if len(b$)<83 then b$=left$(s9$,83-len(b$))+b$
1597 w$=a$+b$:w$=left$(w$,64)+left$(lg$+"            ",12)+"s"+mid$(w$,78)
1598 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
1599 print#3,left$(w$,83):print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(85):print#3,mid$(w$,84)
1600 close 3:open 3,8,3,su$:print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
1601 input#3,s$:s$=left$(s$,36)+"s"+mid$(s$,38):print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1):print#3,s$:close 3:close 15
1602 return
1700 gosub 2200
1703 print "  going offline..."
1704 print chr$(154);h$;chr$(5)
1706 cm$="bye":gosub 2000
1707 gosub 2010
1709 for i=1 to 500:next i
1710 print#2,"+++";
1711 for i=1 to 500:next i
1712 print#2,"ath"+chr$(13);
1713 for i=1 to 300:next i
1715 ol=0
1716 print " disconnected."
1717 print
1718 print " press any key..."
1719 get w$:if w$="" then 1719
1720 if sc=1 then gosub 200:goto 102
1721 sc=0:gosub 500:goto 102
1750 gosub 2200
1753 print "  syncing logbook..."
1754 print chr$(154);h$;chr$(5)
1756 if pq>0 then gosub 1550
1758 cm$="sync,"+li$:gosub 2000
1759 gosub 2010
1760 if left$(rl$,4)<>"!log" then print " sync failed: ";rl$:goto 1795
1761 sn=val(mid$(rl$,6))
1762 print " received ";sn;" qsos from qrz"
1763 if sn=0 then gosub 2010:goto 1795
1765 open 15,8,15:open 3,8,3,da$:open 5,8,5,su$
1766 sa=0:for si=1 to sn
1767 gosub 2010:gosub 240
1771 rc=rc+1:sa=sa+1
1772 w$=left$(p2$+"            ",12)
1773 w$=w$+left$(p3$+"      ",6)
1774 w$=w$+left$(p4$+"      ",6)
1775 w$=w$+left$(p6$+"        ",8)
1776 w$=w$+left$(p7$+"    ",4)
1777 w$=w$+left$(p5$+"          ",10)
1778 w$=w$+left$("599   ",3)
1779 w$=w$+left$("599   ",3)
1780 w$=w$+left$(mc$+"            ",12)
1781 w$=w$+left$(p1$+"            ",12)
1782 w$=w$+"s":li$=p1$
1783 w$=w$+left$("                                        ",40)
1784 w$=w$+left$("      ",6)
1785 w$=w$+left$("                              ",30)
1786 w$=w$+left$("             ",13)
1787 lo=rc and 255:hi=int(rc/256)
1788 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
1789 print#3,left$(w$,83):print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(85):print#3,mid$(w$,84)
1790 s$=left$(p2$+"          ",10)+left$(p3$+"    ",4)+left$(p4$+"    ",4)+left$(p6$+"        ",8)+left$(p7$+"    ",4)+"599599s  "
1791 print#15,"p"+chr$(5)+chr$(lo)+chr$(hi)+chr$(1):print#5,s$
1792 print#2,"k"+chr$(13);:if sa/10=int(sa/10) then print " stored ";sa;" of ";sn
1793 next si:close 3:close 5:close 15
1794 gosub 2010
1795 gosub 2460
1796 print
1797 print " sync complete: ";sa;" qsos added"
1798 print " total records: ";rc
1799 print:print " press any key..."
1800 get w$:if w$="" then 1800
1801 sc=0:gosub 500:goto 102
1900 if rc=0 then return
1904 open 15,8,15
1905 open 3,8,3,su$
1906 ps=lp*19
1907 pc=19:if ps+pc>rc then pc=rc-ps
1908 if pc<1 then close 3:close 15:return
1909 for i=1 to pc
1910 rn=rc-ps-i+1
1911 lo=rn and 255:hi=int(rn/256)
1912 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
1913 input#3,w$
1915 xc$(i)=left$(w$,10)
1916 xb$(i)=mid$(w$,11,4)+"|"+mid$(w$,15,4)+"|"
1917 xd$(i)=mid$(w$,19,8)+"|"+mid$(w$,27,4)
1918 xr$(i)=mid$(w$,31,3)+"|"+mid$(w$,34,3)
1920 next i
1921 close 3:close 15
1922 return
2000 print#2,cm$+chr$(13);
2003 return
2010 rl$="":rt=0
2011 get#2,a$
2012 if a$="" or a$=chr$(0) then rt=rt+1:if rt>5000 then return
2013 if a$="" or a$=chr$(0) then 2011
2014 rt=0:if a$=chr$(10) then 2011
2015 if a$=chr$(13) then return
2016 if len(rl$)<250 then rl$=rl$+a$
2018 goto 2011
2200 print chr$(147);chr$(5);
2203 print chr$(154);chr$(18);"                                       ";chr$(146)
2205 print chr$(19);
2206 if sc=1 then print chr$(154);chr$(18);"  pota spots ";chr$(146);
2207 if sc=0 then print chr$(154);chr$(18);"  qso log ";chr$(146);
2208 if sc=2 then print chr$(154);chr$(18);"  new qso ";chr$(146);
2209 if sc=3 then print chr$(154);chr$(18);"  qso detail ";chr$(146);
2211 print chr$(154);chr$(18);" de ";mc$;" ";chr$(146)
2212 print chr$(5);:return
2220 st$=""
2221 if ol=1 then st$="online"
2222 if ol=0 then st$="offline"
2223 st$=st$+" | "+str$(rc)+" qsos"
2224 if pq>0 then st$=st$+" | pend:"+str$(pq)
2225 print chr$(159);left$(st$,40);chr$(5)
2226 return
2260 poke 214,23:print
2262 print chr$(154);chr$(18);"f1=spt f3=log f4=cfg f5=nw f6=syn f7=on";chr$(146);chr$(5);
2263 return
2400 open 15,8,15
2403 open 4,8,4,"hamlog.cfg,s,r"
2404 input#15,en,em$,et$,es$
2405 if en<>0 then close 4:close 15:goto 2500
2406 input#4,sv$
2407 input#4,pt$
2408 input#4,mc$
2409 input#4,bd$
2410 input#4,mn$
2411 input#4,mg$
2412 close 4:close 15
2413 return
2430 open 15,8,15,"s0:hamlog.cfg":close 15
2431 open 4,8,4,"hamlog.cfg,s,w"
2432 print#4,sv$
2433 print#4,pt$
2434 print#4,mc$
2435 print#4,bd$
2436 print#4,mn$
2437 print#4,mg$
2438 close 4
2439 return
2450 open 15,8,15
2451 open 4,8,4,"hamlog.idx,s,r"
2452 input#15,en,em$,et$,es$
2453 if en<>0 then close 4:close 15:rc=0:li$="0":return
2454 input#4,rc
2455 input#4,li$
2456 close 4:close 15
2457 return
2460 open 15,8,15,"s0:hamlog.idx":close 15
2461 open 4,8,4,"hamlog.idx,s,w"
2462 print#4,rc
2463 print#4,li$
2464 close 4
2465 return
2480 pq=0
2481 open 15,8,15
2482 open 4,8,4,"hamlog.que,s,r"
2483 input#15,en,em$,et$,es$
2484 if en<>0 then close 4:close 15:return
2485 if st and 64 then 2490
2486 input#4,qc$
2487 if st and 64 then 2490
2488 pq=pq+1:goto 2485
2490 close 4:close 15
2491 return
2500 close 4:close 15
2503 print chr$(147);chr$(5);
2504 print chr$(154);e$;chr$(5)
2505 print "       station setup"
2506 print chr$(154);e$;chr$(5)
2507 print
2508 print " no logbook found. let's set up"
2509 print " your station."
2510 print
2512 input " your callsign: ";mc$
2513 if mc$="" then print " callsign required!":goto 2512
2514 print
2516 print " look up on qrz? (y/n)"
2517 get w$:if w$="" then 2517
2518 if w$<>"y" then 2550
2520 print:print " server ip [";sv$;"]:"
2521 input " ";ts$:if ts$<>"" then sv$=ts$
2522 print " port [";pt$;"]:"
2523 input " ";ts$:if ts$<>"" then pt$=ts$
2524 print:print " connecting..."
2525 print
2527 print#2,"atdt"+sv$+":"+pt$+chr$(13);
2528 cf=0:for w=1 to 2000
2529 get#2,a$:if a$>=chr$(32) and a$<chr$(127) then cf=1
2530 if a$=chr$(13) and cf=1 then w=2000
2531 next w:cm$="hello":gosub 2000
2532 gosub 2010
2533 if left$(rl$,3)<>"!ok" then print " connect failed":goto 2550
2534 gosub 240:ut$=p4$:uh$=p5$
2536 cm$="lookup,"+mc$:gosub 2000
2537 gosub 2010
2538 if left$(rl$,10)<>"!lookup,ok" then print " not found on qrz":goto 2550
2539 gosub 2010:gosub 240
2540 mn$=p2$:mg$=p7$
2541 if mn$<>"" then print " name: ";mn$
2542 if mg$<>"" then print " grid: ";mg$
2543 cm$="bye":gosub 2000:gosub 2010
2544 for i=1 to 500:next i
2545 print#2,"+++";
2546 for i=1 to 500:next i
2547 print#2,"ath"+chr$(13);
2548 for i=1 to 300:next i
2549 goto 2570
2550 print
2552 input " your name: ";mn$
2553 input " your grid (e.g. dm43): ";mg$
2554 print
2556 print " server ip [";sv$;"]:"
2557 input " ";ts$:if ts$<>"" then sv$=ts$
2558 print " port [";pt$;"]:"
2559 input " ";ts$:if ts$<>"" then pt$=ts$
2570 print
2571 print " saving configuration..."
2572 gosub 2430
2573 print " creating logbook..."
2575 rc=0:li$="0"
2576 gosub 2460
2577 print
2578 print " setup complete!"
2579 print " station: ";mc$
2580 if mn$<>"" then print " name:    ";mn$
2581 if mg$<>"" then print " grid:    ";mg$
2582 print
2583 return
2600 print chr$(147);chr$(5);
2603 print chr$(154);e$;chr$(5)
2604 print "       edit configuration"
2605 print chr$(154);e$;chr$(5)
2606 print
2607 print " current settings:"
2608 print "  1. callsign: ";mc$
2609 print "  2. name:     ";mn$
2610 print "  3. grid:     ";mg$
2611 print "  4. server:   ";sv$
2612 print "  5. port:     ";pt$
2613 print "  6. baud:     ";bd$
2614 print
2615 print " enter number to edit (0=done):"
2616 get w$:if w$="" then 2616
2617 if w$="0" then 2650
2618 if w$="1" then input " callsign: ";mc$:goto 2600
2619 if w$="2" then input " name: ";mn$:goto 2600
2620 if w$="3" then input " grid: ";mg$:goto 2600
2621 if w$="4" then input " server ip: ";sv$:goto 2600
2622 if w$="5" then input " port: ";pt$:goto 2600
2623 if w$="6" then input " baud: ";bd$:goto 2600
2624 goto 2616
2650 print:print " saving..."
2651 gosub 2430
2652 print " configuration saved."
2653 for w=1 to 500:next w
2654 sc=0:gosub 500
2655 return
2700 poke 53280,6:poke 53281,0
2703 a$=chr$(154)+chr$(18):b$=chr$(146)
2704 print a$;"                                       ";b$
2705 print a$;" ";b$;"                                     ";a$;" ";b$
2706 print a$;" ";b$;chr$(158);"            ham commander            ";a$;" ";b$
2707 print a$;" ";b$;chr$(155);"                v2.0                 ";a$;" ";b$
2708 print a$;" ";b$;"                                     ";a$;" ";b$
2709 print a$;"                                       ";b$
2710 print
2711 print chr$(30);"                  |"
2712 print "                  |"
2713 print "       ))  (      |      )  (("
2714 print "      )))  (      |      )  ((("
2715 print "       ))  (      |      )  (("
2716 print "                  |"
2717 print "                  |"
2718 print chr$(154);chr$(18);"           [===========]           ";chr$(146)
2719 print chr$(154);chr$(18);"           [===========]           ";chr$(146)
2720 print
2721 print chr$(5);"   a commodore 64 ham radio logger"
2722 print chr$(159);"      qrz + pota integration"
2723 print
2724 print chr$(151);"            by john burns"
2725 print:print
2726 print chr$(155);"       press any key to start"
2728 fc$=chr$(7)+chr$(1)+chr$(13)+chr$(3)+chr$(14)+chr$(15)
2729 for cc=1 to 6:cl=asc(mid$(fc$,cc,1))
2730 for cx=55377 to 55413:poke cx,cl:next cx
2731 for dw=0 to 100:next dw:get w$:if w$<>"" then 2740
2732 next cc:goto 2729
2740 return
