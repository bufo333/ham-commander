1 poke 56835,42:hw=-(peek(56835)=42):poke 56835,0:if hw=0 then open 2,2,0,chr$(8)+chr$(0)
9 poke 53280,0:poke 53281,0:print chr$(147);:gosub 2710
10 print chr$(147);chr$(5);
11 print "  ham commander v2.2"
12 print chr$(159);"  loading..."
15 sv$="127.0.0.1":pt$="6400"
16 mc$="n0call":bd$="1200"
17 mn$="":mg$=""
18 ol=0:sc=0:rc=0:li$="0":pq=0:sp=0:lp=0:sl=0:fi=0:sf=0:sr=0:dc=0:mx=3500:dn=1:dk=81
19 fb$="":fm$=""
28 ut$="00000000":uh$="0000"
29 s9$="                                                                                   "
30 if hw then for i=0to145:read a:poke 49152+i,a:next:for i=0to82:read a:poke 49920+i,a:next:sys 49152
31 dim ca$(20),fq$(20),mo$(20),rf$(20),sd$(20)
35 dim xc$(20),xb$(20),xd$(20),xr$(20)
40 dim fx(20)
42 h$="---------------------------------------"
43 e$="======================================="
44 da$="hamlog.dat,l,"+chr$(168)
45 su$="hamlog.sum,l,"+chr$(40)
50 gosub 2400
51 if hw then gosub 2870
52 gosub 2450
54 gosub 2480
55 print " station: ";mc$
56 if mn$<>"" then print " op name: ";mn$
57 if mg$<>"" then print "    grid: ";mg$
58 print "  server: ";sv$;":";pt$
59 print " records: ";rc-dc;" / ";mx
60 if dn>1 then print "    disk: #";dn
61 if pq>0 then print " pending: ";pq
62 print:if dn>1 then gosub 80
63 print " utc date yyyymmdd (enter=skip):"
64 input " ";td$
65 if td$<>"" then ut$=td$
66 if td$<>"" then print " enter utc time (hhmm):"
67 if td$<>"" then input " ";th$:uh$=th$
68 print
69 print " press any key..."
70 get w$:if w$="" then 70
72 lp=0:sc=0:gosub 500:goto 102
80 print " load archive disk? (y/n)"
81 get w$:if w$="" then 81
82 if w$<>"y" then return
83 print:input " disk # ";td
84 if td<1 or td=dn then print " cancelled.":return
85 gosub 1830:if ef then return
86 dn=td:gosub 2400:gosub 2450:gosub 2480
87 print " loaded disk #";dn;" (";rc-dc;"/";mx;")"
88 return
102 get k$:if k$="" then 102
104 if k$=chr$(133) and sp>0 then sc=1:sl=0:gosub 300:goto 102
105 if k$=chr$(133) and ol=1 then sc=1:gosub 1300:goto 102
106 if k$=chr$(133) and ol=0 then sc=1:gosub 200:goto 102
107 if k$=chr$(134) then sc=0:lp=0:gosub 500:goto 102
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
128 if k$="d" and sc=3 and sf=0 then gosub 843:goto 102
129 if k$="s" and sc=0 and rc>0 then gosub 700:goto 102
130 if k$="+" and sc=0 then gosub 575:goto 102
131 if k$="-" and sc=0 then gosub 577:goto 102
132 if k$="r" and sc=1 and ol=1 then gosub 200:goto 102
133 if k$="<" and sc=0 and dn>1 then gosub 1850:goto 102
135 if k$=">" and sc=0 then gosub 1860:goto 102
136 goto 102
150 if sc=0 then gosub 561:return
151 if sc=1 then gosub 260:return
152 if sc=4 then gosub 760:return
153 return
160 if sc=0 then gosub 571:return
161 if sc=1 then gosub 270:return
162 if sc=4 then gosub 770:return
163 return
170 if sc=0 then gosub 580:return
171 if sc=1 then gosub 280:return
172 if sc=4 then gosub 780:return
173 return
180 if sc=3 and sf=1 then sf=0:sc=4:gosub 735:return
181 if sc=3 then sc=0:gosub 500:return
182 if sc=4 then sc=0:gosub 500:return
183 return
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
216 if sp<1 then gosub 2010:print " no spots.":gosub 2260:return
217 gosub 2200:print chr$(159);"loading ";sp;" spots...";chr$(5)
218 print chr$(154);h$;chr$(5)
219 for i=1 to sp
220 gosub 2010
221 gosub 240
222 if i<1 or i>20 then 226
223 ca$(i)=p1$:fq$(i)=p2$:mo$(i)=p3$
224 rf$(i)=p4$:sd$(i)=""
225 print left$(p1$+"          ",10);left$(p2$+"       ",7);" ";left$(p3$+"    ",4);" ";left$(p4$+"          ",10)
226 s$="k"+chr$(13):gosub 2880
227 next i
228 gosub 2010
229 gosub 290:sl=0:tp=0
230 st$="online":if fb$<>"" or fm$<>"" then st$=st$+" | "+fb$+" "+fm$
231 st$=st$+" | "+str$(fi)+" spots":poke 214,0:print:print chr$(159);left$(st$+"                                        ",39);chr$(5)
232 poke 214,fi+2:print:print chr$(154);h$;chr$(5):print chr$(155);" ent=log f2=filt r=rfsh ";chr$(17);chr$(145);"=scrl";chr$(5)
233 gosub 2260:i=0:gosub 295:poke 214,2:print:print chr$(158);chr$(18);left$(ln$+"                                        ",39);chr$(146);chr$(5);
234 return
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
261 if sl>=mx then return
262 os=sl:sl=sl+1
263 if sl-tp>=19 then tp=tp+1:gosub 300:return
264 gosub 297:return
270 if sl<1 then return
271 os=sl:sl=sl-1
272 if sl<tp then tp=tp-1:gosub 300:return
273 gosub 297:return
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
295 ix=fx(i+1):ln$=left$(ca$(ix)+"          ",10)+left$(fq$(ix)+"       ",7)+" "+left$(mo$(ix)+"    ",4)+" "+left$(rf$(ix)+"          ",10)
296 return
297 i=os:gosub 295:poke 214,(os-tp)+2:print
298 print left$(ln$+"                                        ",39);
299 i=sl:gosub 295:poke 214,(sl-tp)+2:print:print chr$(158);chr$(18);left$(ln$+"                                        ",39);chr$(146);chr$(5);:return
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
333 print chr$(155);" ent=log f2=filt r=rfsh ";chr$(17);chr$(145);"=scrl";chr$(5)
334 gosub 2260
335 return
500 gosub 2200
504 st$=""
505 if ol=1 then st$="online"
506 if ol=0 then st$="offline"
507 st$=st$+" | "+str$(rc-dc)+" qsos"
508 if pq>0 then st$=st$+" | pend:"+str$(pq)
509 if rc>mx*0.8 then st$=st$+" "+str$(int(rc/mx*100))+"%"
510 print chr$(159);left$(st$+"                                        ",39);chr$(5)
512 if rc=0 then print:print "  no qsos yet. press f5 to add.":gosub 2260:sl=0:return
513 gosub 1900
515 sl=0:vw=19
516 poke 214,pc+1:print:print chr$(154);h$;chr$(5)
517 print chr$(155);" pg ";lp+1;" s=srch ent=dtl +/- <> ";chr$(17);chr$(145);"=scrl";chr$(5):gosub 2260
518 i=0:gosub 590:poke 214,1:print:print chr$(158);chr$(18);left$(ln$+"                                        ",39);chr$(146);chr$(5);
519 return
540 gosub 2200:gosub 2220
546 for i=0 to vw-1
547 if i>=pc then print:goto 555
548 if i=sl then print chr$(158);chr$(18);
550 gosub 590
551 print ln$;
552 if i=sl then print chr$(146);chr$(5);
553 print
555 next i
556 print chr$(154);h$;chr$(5)
557 print chr$(155);" pg ";lp+1;" s=srch ent=dtl +/- <> ";chr$(17);chr$(145);"=scrl";chr$(5)
558 gosub 2260
559 return
561 if pc<1 then return
563 if sl<pc-1 then os=sl:sl=sl+1:gosub 600:return
565 if pc>=19 then lp=lp+1:gosub 1900:sl=0:gosub 540
566 return
571 if sl>0 then os=sl:sl=sl-1:gosub 600:return
573 if lp>0 then lp=lp-1:gosub 1900:sl=18:gosub 540
574 return
575 if pc>=19 then lp=lp+1:gosub 1900:sl=0:gosub 540
576 return
577 if lp>0 then lp=lp-1:gosub 1900:sl=0:gosub 540
578 return
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
700 gosub 2200
701 sc=4:print " search by callsign:"
702 print:input " search: ";sq$
703 if sq$="" then sc=0:gosub 500:return
704 print " searching ";rc;" records..."
705 sr=0
706 open 15,8,15:open 3,8,3,su$
707 for rn=1 to rc
708 if sr>=20 then 718
709 lo=rn and 255:hi=int(rn/256)
710 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
711 input#3,w$
712 if left$(w$,len(sq$))<>sq$ then 718
713 sr=sr+1:fx(sr)=rn
714 xc$(sr)=left$(w$,10)
715 xb$(sr)=mid$(w$,11,4)+"|"+mid$(w$,15,4)+"|"
716 xd$(sr)=mid$(w$,19,8)+"|"+mid$(w$,27,4)
717 xr$(sr)=mid$(w$,31,3)+"|"+mid$(w$,34,3)
718 next rn
719 close 3:close 15
720 if sr=0 then print " no matches.":for w=1 to 1000:next w:sc=0:gosub 500:return
732 sl=0:gosub 735:return
735 gosub 2200
736 print chr$(159);" search: ";sq$;" (";right$(str$(sr),len(str$(sr))-1);" found)";chr$(5)
737 print chr$(154);h$;chr$(5)
738 for i=0 to 18
739 if i>=sr then print:goto 744
740 if i=sl then print chr$(158);chr$(18);
741 gosub 590
742 print ln$;
743 if i=sl then print chr$(146);chr$(5);
744 print:next i
745 print chr$(154);h$;chr$(5)
746 print chr$(155);" enter=detail  del=back";chr$(5)
747 gosub 2260:return
760 if sl<sr-1 and sl<18 then os=sl:sl=sl+1:gosub 600
761 return
770 if sl>0 then os=sl:sl=sl-1:gosub 600
771 return
780 if sr=0 then return
781 rn=fx(sl+1):if rn<1 then return
782 gosub 2200:print "  loading detail..."
783 sf=1:sc=3:gosub 806:return
800 gosub 2200
803 print "  loading detail..."
805 rn=fx(sl+1)
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
851 rn=fx(sl+1):gosub 890:return
890 open 15,8,15
891 open 3,8,3,da$
892 lo=rn and 255:hi=int(rn/256)
893 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
894 input#3,a$:print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(85)
895 input#3,b$:if len(b$)<83 then b$=left$(s9$,83-len(b$))+b$
896 w$=a$+b$:of$=mid$(w$,77,1):w$=left$(w$,76)+"d"+mid$(w$,78)
897 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
898 print#3,left$(w$,83):print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(85):print#3,mid$(w$,84)
899 close 3:open 3,8,3,su$
900 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
901 input#3,w$:w$=left$(w$,36)+"d"+mid$(w$,38):print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1):print#3,w$
902 close 3:close 15
903 dc=dc+1:if of$="n" or of$="p" then pq=pq-1:if pq<0 then pq=0
904 gosub 2462
905 print "  qso deleted."
906 for w=1 to 500:next w
907 sc=0:gosub 500:return
1000 gosub 2200
1003 print "  new qso entry"
1004 print chr$(154);h$;chr$(5)
1005 if rc>=mx then print:print "  disk full! (";rc;"/";mx;")":print "  archive via f4 config menu.":gosub 2260:return
1006 if nc$<>"" then print "  callsign: ";nc$:print "  del=cancel":goto 1010
1007 print:input "  callsign: ";nc$
1008 if nc$="" then sc=0:gosub 500:return
1009 goto 1012
1010 get w$:if w$="" then 1010
1011 if w$=chr$(20) then nc$="":nf$="":nm$="":nb$="":sc=1:sl=0:gosub 300:return
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
1024 print "  date yyyymmdd [";nd$;"]: ";
1025 input "";td$
1026 if td$<>"" then nd$=td$
1027 print "  time hhmm [";nt$;"]: ";
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
1061 gosub 2462
1063 print:print "  qso saved! #";rc
1064 if pq>0 and ol=0 then print "  pending sync: ";pq
1065 if rc>=mx then print chr$(18);"  disk full!";chr$(146);" archive via f4"
1066 if rc>=mx*0.9 and rc<mx then print "  disk ";int(rc/mx*100);"% full"
1067 if ol=1 then gosub 1170
1068 for w=1 to 1000:next w
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
1150 open 15,8,15:open 4,8,4,"hamlog.que,s,a"
1151 input#15,en,em$,et$,es$:if en=0 then 1155
1152 close 4:open 4,8,4,"hamlog.que,s,w"
1155 print#4,nc$;",";nb$;",";nm$;",";nf$;",";nd$;",";nt$;",";rs$;",";rr$;",";co$;",";rc
1156 close 4:close 15
1157 return
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
1195 li$=lg$:print "  synced! logid: ";lg$
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
1511 s$="atdt"+sv$+":"+pt$+chr$(13):gosub 2880
1512 print " connecting";
1513 cf=0:for w=1 to 2000
1514 gosub 2890
1515 if a$="" or a$=chr$(0) then 1518
1516 if a$=chr$(13) and cf=1 then print:w=2000
1517 if a$>=chr$(32) and a$<chr$(127) then print a$;:cf=1
1518 next w
1519 print
1520 for w=1to200:gosub 2890:next
1521 cm$="hello":gosub 2000
1522 gosub 2010
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
1551 open 15,8,15:open 4,8,4,"hamlog.que,s,r"
1552 input#15,en,em$,et$,es$
1553 if en>0 then close 4:close 15:goto 1580
1554 uq=0
1555 input#4,qc$,qb$,qm$,qf$,qd$,qt$,qs$,qr$,qo$,qn$
1556 ef=(st and 64)
1558 cm$="add,"+qc$+","+qb$+","+qm$+","+qf$+","+qd$+","+qt$+","+qs$+","+qr$+","+qo$
1559 gosub 2000:gosub 2010
1560 if left$(rl$,7)="!add,ok" then uq=uq+1:print " synced: ";qc$
1561 if left$(rl$,7)<>"!add,ok" then print " failed: ";qc$
1563 rn=val(qn$):if rn>0 and left$(rl$,7)="!add,ok" then close 15:gosub 1590:open 15,8,15
1564 if ef then 1580
1565 goto 1555
1580 close 4:close 15
1581 pq=pq-uq:if pq<0 then pq=0
1582 print " uploaded: ";uq;" qsos"
1584 if pq=0 then open 15,8,15,"s0:hamlog.que":close 15
1585 gosub 2462
1586 return
1590 lg$=mid$(rl$,9):li$=lg$
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
1710 s$="+++":gosub 2880
1711 for i=1 to 500:next i
1712 s$="ath"+chr$(13):gosub 2880
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
1758 cm$="sync,"+li$+","+str$(mx-rc):gosub 2000
1759 gosub 2010
1760 if left$(rl$,4)<>"!log" then print " sync failed: ";rl$:goto 1795
1761 sn=val(mid$(rl$,6))
1762 print " received ";sn;" qsos from qrz"
1763 if sn=0 then gosub 2010:goto 1796
1765 open 15,8,15:open 3,8,3,da$:open 5,8,5,su$
1766 sa=0:for si=1 to sn
1767 gosub 2010:gosub 240
1771 if rc>=mx then print " disk full!":goto 1794
1772 rc=rc+1:sa=sa+1:w$=left$(p2$+"            ",12)
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
1792 if si<sn then s$="k"+chr$(13):gosub 2880
1793 if sa/10=int(sa/10) then print " stored ";sa;" of ";sn
1794 next si:close 3:close 5:close 15
1795 s$="k"+chr$(13):gosub 2880:gosub 2010
1796 gosub 2462
1797 print
1798 print " sync complete: ";sa;" qsos added"
1799 print " total records: ";rc
1800 print:print " press any key..."
1801 get w$:if w$="" then 1801
1802 sc=0:gosub 500:goto 102
1830 ef=0:td$=right$(str$(td+100),2):df$="hamlog-"+td$+".d"+right$(str$(dk),2)
1831 open 15,8,15,"cd:"+chr$(95):input#15,en,em$,et$,es$:close 15
1832 if en>0 then 1840
1833 open 15,8,15,"cd:"+df$:input#15,en,em$,et$,es$:close 15
1834 if en=0 then print " mounted ";df$:return
1835 print " ";df$;" not found!"
1836 od$=right$(str$(dn+100),2):of$="hamlog-"+od$+".d"+right$(str$(dk),2)
1837 open 15,8,15,"cd:"+of$:close 15
1838 ef=1:for w=1 to 1000:next w:return
1840 gosub 2200:print " insert disk #";td
1841 print:print " swap disk, then"
1842 print " press any key..."
1843 print:print " del=cancel"
1844 get w$:if w$="" then 1844
1845 if w$=chr$(20) then ef=1
1846 return
1850 td=dn-1:gosub 1830:if ef then gosub 500:return
1851 dn=td:goto 1870
1860 td=dn+1:gosub 1830:if ef then gosub 500:return
1861 dn=td
1870 gosub 2400:gosub 2450:gosub 2480
1871 lp=0:sl=0:gosub 500
1872 return
1900 if rc=0 then return
1904 open 15,8,15
1905 open 3,8,3,su$
1906 pc=0:sk=0
1907 for j=rc to 1 step -1
1908 lo=j and 255:hi=int(j/256)
1909 print#15,"p"+chr$(3)+chr$(lo)+chr$(hi)+chr$(1)
1910 input#3,w$
1911 if mid$(w$,37,1)="d" then 1920
1912 if sk<lp*19 then sk=sk+1:goto 1920
1913 pc=pc+1:fx(pc)=j
1914 xc$(pc)=left$(w$,10)
1915 xb$(pc)=mid$(w$,11,4)+"|"+mid$(w$,15,4)+"|"
1916 xd$(pc)=mid$(w$,19,8)+"|"+mid$(w$,27,4)
1917 xr$(pc)=mid$(w$,31,3)+"|"+mid$(w$,34,3):i=pc-1:gosub 590:print ln$
1918 if pc>=19 then j=1
1920 next j
1921 close 3:close 15
1922 return
2000 s$=cm$+chr$(13):gosub 2880
2003 return
2010 rl$="":rt=0:if hw then 2020
2011 gosub 2890
2012 if a$="" or a$=chr$(0) then rt=rt+1:if rt>2000 then return
2013 if a$="" or a$=chr$(0) then 2011
2014 rt=0:if a$=chr$(10) then 2011
2015 if a$=chr$(13) then return
2016 if len(rl$)<250 then rl$=rl$+a$
2018 goto 2011
2020 sys 49920:ln=peek(49392):if ln=0 then rt=rt+1:if rt<20 then 2020
2021 for qi=0toln-1:rl$=rl$+chr$(peek(49664+qi)):next:return
2200 print chr$(147);chr$(5);
2203 print chr$(154);chr$(18);"                                       ";chr$(146)
2205 print chr$(19);
2206 if sc=1 then print chr$(154);chr$(18);"  pota spots ";chr$(146);
2207 if sc=0 then print chr$(154);chr$(18);"  qso log ";chr$(146);
2208 if sc=2 then print chr$(154);chr$(18);"  new qso ";chr$(146);
2209 if sc=3 then print chr$(154);chr$(18);"  qso detail ";chr$(146);
2210 if sc=4 then print chr$(154);chr$(18);"  search ";chr$(146);
2211 print chr$(154);chr$(18);" de ";mc$;" ";chr$(146)
2212 print chr$(5);:return
2220 st$=""
2221 if ol=1 then st$="online"
2222 if ol=0 then st$="offline"
2223 st$=st$+" | "+str$(rc-dc)+" qsos"
2224 if pq>0 then st$=st$+" | pend:"+str$(pq)
2225 if rc>mx*0.8 then st$=st$+" "+str$(int(rc/mx*100))+"%"
2226 print chr$(159);left$(st$,40);chr$(5)
2227 return
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
2456 if not(st and 64) then input#4,dc
2457 if not(st and 64) then input#4,mx
2458 if not(st and 64) then input#4,dn
2459 if not(st and 64) then input#4,dk
2460 if dk<>64 then dk=81
2461 close 4:close 15:return
2462 open 15,8,15,"s0:hamlog.idx":close 15
2463 open 4,8,4,"hamlog.idx,s,w"
2464 print#4,rc
2465 print#4,li$
2466 print#4,dc
2467 print#4,mx
2468 print#4,dn
2469 print#4,dk
2470 close 4
2471 return
2480 pq=0
2481 open 15,8,15
2482 open 4,8,4,"hamlog.que,s,r"
2483 input#15,en,em$,et$,es$
2484 if en<>0 then close 4:close 15:return
2485 if st and 64 then 2490
2486 input#4,qc$,qb$,qm$,qf$,qd$,qt$,qs$,qr$,qo$,qn$
2487 if st and 64 then pq=pq+1:goto 2490
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
2527 s$="atdt"+sv$+":"+pt$+chr$(13):gosub 2880
2528 cf=0:for w=1 to 2000
2529 gosub 2890:if a$>=chr$(32) and a$<chr$(127) then cf=1
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
2545 s$="+++":gosub 2880
2546 for i=1 to 500:next i
2547 s$="ath"+chr$(13):gosub 2880
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
2570 print " disk type:"
2571 print "  1. d81 (3500 records)"
2572 print "  2. d64 (600 records)"
2573 get w$:if w$="" then 2573
2574 if w$="2" then dk=64:mx=600
2575 print " using d";dk;" (";mx;" max)"
2576 print
2577 print " saving configuration..."
2578 gosub 2430
2579 print " creating logbook..."
2580 rc=0:li$="0"
2581 gosub 2462
2582 print
2583 print " setup complete!"
2584 print " station: ";mc$
2585 if mn$<>"" then print " name:    ";mn$
2586 if mg$<>"" then print " grid:    ";mg$
2587 print
2588 return
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
2614 print "  7. archive disk"
2615 print "  8. disk type: d";dk
2616 print:print "  disk #";dn;" | ";rc;"/";mx;" (";int(rc/mx*100);"%)"
2617 print " enter number to edit (0=done):"
2618 get w$:if w$="" then 2618
2619 if w$="0" then 2650
2620 if w$="1" then input " callsign: ";mc$:goto 2600
2621 if w$="2" then input " name: ";mn$:goto 2600
2622 if w$="3" then input " grid: ";mg$:goto 2600
2623 if w$="4" then input " server ip: ";sv$:goto 2600
2624 if w$="5" then input " port: ";pt$:goto 2600
2625 if w$="6" then input " baud: ";bd$:goto 2600
2626 if w$="7" then gosub 2670:goto 2600
2627 if w$="8" then dk=145-dk:if dk=81 then mx=3500:goto 2600
2628 if w$="8" and rc>600 then dk=81:mx=3500:print " too many records for d64!":for w=1 to 1000:next w:goto 2600
2629 if w$="8" then mx=600:goto 2600
2630 goto 2618
2650 print:print " saving..."
2651 gosub 2430
2652 print " configuration saved."
2653 for w=1 to 500:next w
2654 sc=0:gosub 500
2655 return
2670 print chr$(147);chr$(5);
2671 print chr$(154);e$;chr$(5)
2672 print "       archive disk"
2673 print chr$(154);e$;chr$(5)
2674 print
2675 print " current disk #";dn
2676 print " records: ";rc;" / ";mx
2677 print
2678 print " this will:"
2679 print "  - format a new disk"
2680 print "  - reset log to empty"
2681 print "  - keep your config"
2682 print "  - increment disk #"
2683 print
2684 print " next disk: hamlog-"
2685 print right$(str$(dn+101),2);".d";dk
2686 print
2687 print " y=archive  n=cancel"
2688 get w$:if w$="" then 2688
2689 if w$<>"y" then return
2690 td=dn+1:gosub 1830:if ef then return
2691 print:print " formatting..."
2692 open 15,8,15,"n:hamlog,hl":close 15
2693 dn=td:rc=0:dc=0:li$="0":pq=0:mx=3600:if dk=64 then mx=700
2694 gosub 2430
2695 gosub 2462
2696 print " creating log files..."
2697 open 3,8,3,da$:close 3
2698 open 3,8,3,su$:close 3
2699 print:print " disk #";dn;" ready!":print " press any key..."
2700 get w$:if w$="" then 2700
2701 sc=0:gosub 500:return
2710 poke 53280,6:poke 53281,0
2711 a$=chr$(154)+chr$(18):b$=chr$(146)
2712 print a$;"                                       ";b$
2713 print a$;" ";b$;"                                     ";a$;" ";b$
2714 print a$;" ";b$;chr$(158);"            ham commander            ";a$;" ";b$
2715 print a$;" ";b$;chr$(155);"                v2.2                 ";a$;" ";b$
2716 print a$;" ";b$;"                                     ";a$;" ";b$
2717 print a$;"                                       ";b$
2718 print
2719 print chr$(30);"                  |"
2720 print "                  |"
2721 print "       ))  (      |      )  (("
2722 print "      )))  (      |      )  ((("
2723 print "       ))  (      |      )  (("
2724 print "                  |"
2725 print "                  |"
2726 print chr$(154);chr$(18);"           [===========]           ";chr$(146)
2727 print chr$(154);chr$(18);"           [===========]           ";chr$(146)
2728 print
2729 print chr$(5);"   a commodore 64 ham radio logger"
2730 print chr$(159);"      qrz + pota integration"
2731 print
2732 print chr$(151);"            by john burns"
2733 print:print
2734 print chr$(155);"       press any key to start"
2735 for i=0to149:read a:poke 49664+i,a:next
2736 poke 54276,0:poke 54296,15:poke 54272,212:poke 54273,44:poke 54277,0:poke 54278,240
2737 if peek(197)<>64 then 2737
2738 sys 49664:get w$
2750 poke 54296,0:poke 54276,0:return
2760 data 162,0,134,251,189,139,194,201,255,240,53,201,0,240,34,133
2761 data 253,169,17,141,4,212,32,121,194,198,253,208,249,169,16,141
2762 data 4,212,32,121,194,32,94,194,165,197,201,64,208,42,232,208
2763 data 211,32,121,194,32,121,194,165,197,201,64,208,27,232,208,196
2764 data 169,6,133,253,32,121,194,198,253,208,249,32,94,194,165,197
2765 data 201,64,208,4,162,0,240,172,169,16,141,4,212,96,134,252
2766 data 164,251,200,192,6,144,2,160,0,132,251,185,133,194,160,36
2767 data 153,81,216,136,16,250,166,252,96,169,48,160,0,136,208,253
2768 data 233,1,208,247,96,7,1,13,3,14,15,1,1,1,1,0
2769 data 1,3,0,3,3,255
2870 br=val(bd$):bc=30:if br=300 then bc=22
2871 if br=1200 then bc=24
2872 if br=2400 then bc=26
2873 if br=4800 then bc=28
2874 if br=19200 then bc=31
2875 poke 56835,bc:return
2880 if hw=0 then print#2,s$;:return
2881 for qi=1tolen(s$):poke 49392,asc(mid$(s$,qi,1)):sys 49203:next:return
2890 if hw=0 then get#2,a$:return
2891 sys 49217:a=peek(49392):a$="":if a>0 then a$=chr$(a)
2892 return
2900 data 169,0,141,1,222,173,24,3,141,244,192,173,25,3,141,245
2901 data 192,169,0,141,240,192,141,241,192,141,242,192,120,169,113,141
2902 data 24,3,169,192,141,25,3,88,169,30,141,3,222,169,9,141
2903 data 2,222,96,173,1,222,41,16,240,249,173,240,192,141,0,222
2904 data 96,173,242,192,205,241,192,240,14,174,241,192,189,0,193,141
2905 data 240,192,232,142,241,192,96,169,0,141,240,192,96,120,173,244
2906 data 192,141,24,3,173,245,192,141,25,3,88,169,2,141,2,222
2907 data 96,72,138,72,173,1,222,41,8,240,17,173,0,222,174,242
2908 data 192,157,0,193,232,142,242,192,104,170,104,64,104,170,104,108
2909 data 244,192
2910 data 162,0,160,0,140,246,192,140,247,192,173,242,192,205,241,192
2911 data 240,46,142,248,192,172,241,192,185,0,193,200,140,241,192,174
2912 data 248,192,160,0,140,246,192,140,247,192,201,0,240,220,201,10
2913 data 240,216,201,13,240,25,157,0,194,232,224,250,144,204,176,15
2914 data 238,246,192,208,197,238,247,192,173,247,192,201,64,144,187,142
2915 data 240,192,96
