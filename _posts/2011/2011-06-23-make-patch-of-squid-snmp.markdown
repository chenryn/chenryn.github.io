---
layout: post
theme:
  name: twitter
title: patch制作和使用
date: 2011-06-23
category: linux
---

做运维几年没用过patch，说来也怪了~~趁着上一篇自己的小改动，熟悉一下这个命令的简单用法。
首先是patch的制作，用diff命令。
```bashtar zxvf squid-2.7.STABLE9.tar.gz
cp squid-2.7.STABLE9 squid-2.7.STABLE9-old && mv squid-2.7.STABLE9 squid-2.7.STABLE9-new
#然后按照上篇的内容修改squid-2.7.STABLE9-new/里的文件
diff -uNr squid-2.7.STABLE9-old squid-2.7.STABLE9-new > squid-snmp.patch```
这就完成了，好简单啊~来看看patch文件的内容吧：
```cdiff -uNr squid-2.7.STABLE9-old/include/cache_snmp.h squid-2.7.STABLE9-new/include/cache_snmp.h
--- squid-2.7.STABLE9-old/include/cache_snmp.h	2006-09-22 10:49:24.000000000 +0800
+++ squid-2.7.STABLE9-new/include/cache_snmp.h	2011-06-23 13:25:04.000000000 +0800
@@ -125,6 +125,7 @@
     MESH_PTBL_KEEPAL_S,
     MESH_PTBL_KEEPAL_R,
     MESH_PTBL_INDEX,
+    MESH_PTBL_CONN_OPEN,
     MESH_PTBL_HOST,
     MESH_PTBL_END
 };
diff -uNr squid-2.7.STABLE9-old/src/snmp_agent.c squid-2.7.STABLE9-new/src/snmp_agent.c
--- squid-2.7.STABLE9-old/src/snmp_agent.c	2009-06-26 06:58:10.000000000 +0800
+++ squid-2.7.STABLE9-new/src/snmp_agent.c	2011-06-23 13:27:31.000000000 +0800
@@ -264,6 +264,11 @@
 	    index,
 	    ASN_INTEGER);
 	break;
+    case MESH_PTBL_CONN_OPEN:
+        Answer = snmp_var_new_integer(Var->name, Var->name_length,
+            p->stats.conn_open,
+            ASN_INTEGER);
+        break;
     default:
 	*ErrP = SNMP_ERR_NOSUCHNAME;
 	break;
diff -uNr squid-2.7.STABLE9-old/src/snmp_core.c squid-2.7.STABLE9-new/src/snmp_core.c
--- squid-2.7.STABLE9-old/src/snmp_core.c	2008-05-05 07:23:13.000000000 +0800
+++ squid-2.7.STABLE9-new/src/snmp_core.c	2011-06-23 20:36:54.000000000 +0800
@@ -321,7 +321,7 @@
 						snmpAddNode(snmpCreateOid(LEN_SQ_MESH + 3, SQ_MESH, 1, 1, 15),
 						    LEN_SQ_MESH + 3, snmp_meshPtblFn, peer_Inst, 0)),
 					    snmpAddNode(snmpCreateOid(LEN_SQ_MESH + 2, SQ_MESH, 1, 2),
-						LEN_SQ_MESH + 2, NULL, NULL, 15,
+						LEN_SQ_MESH + 2, NULL, NULL, 16,
 						snmpAddNode(snmpCreateOid(LEN_SQ_MESH + 3, SQ_MESH, 1, 2, 1),
 						    LEN_SQ_MESH + 3, snmp_meshPtblFn, peer_InstIndex, 0),
 						snmpAddNode(snmpCreateOid(LEN_SQ_MESH + 3, SQ_MESH, 1, 2, 2),
@@ -351,6 +351,8 @@
 						snmpAddNode(snmpCreateOid(LEN_SQ_MESH + 3, SQ_MESH, 1, 2, 14),
 						    LEN_SQ_MESH + 3, snmp_meshPtblFn, peer_InstIndex, 0),
 						snmpAddNode(snmpCreateOid(LEN_SQ_MESH + 3, SQ_MESH, 1, 2, 15),
+                                                    LEN_SQ_MESH + 3, snmp_meshPtblFn, peer_InstIndex, 0),
+                                                snmpAddNode(snmpCreateOid(LEN_SQ_MESH + 3, SQ_MESH, 1, 2, 16),
 						    LEN_SQ_MESH + 3, snmp_meshPtblFn, peer_InstIndex, 0))),
 					snmpAddNode(snmpCreateOid(LEN_SQ_MESH + 1, SQ_MESH, 2),
 					    LEN_SQ_MESH + 1, NULL, NULL, 1,```
制作练完了，再练一次使用：
```bashcd squid-2.7.STABLE9-old
mv ../squid-snmp.patch .
patch -p1 < squid-snmp.patch```
-p指定从那层目录开始，因为之前diff的时候顶层目录分别叫old和new，如果在其他地方时候的话，别人的目录肯定不会这么命名的，所以就往里进一层，然后用-p1来patch。
然后more一下那三个文件，确认都修改了~
最后回退patch：
```bashpatch -R -p1 < squid-snmp.patch```
完成~
