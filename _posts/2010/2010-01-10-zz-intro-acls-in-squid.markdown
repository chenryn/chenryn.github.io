---
layout: post
title: Squid的ACL分类
date: 2010-01-10
category: squid
---

在找http_status的acl用法时，看到这么一句“This clause supports both fast and slow acl types”。acl还分快慢呢~~赶紧去wiki看：<a href="http://wiki.squid-cache.org/SquidFaq/SquidAcl#Fast_and_Slow_ACLs">http://wiki.squid-cache.org/SquidFaq/SquidAcl#Fast_and_Slow_ACLs</a>

    Some ACL types require information which may not
    be already available to Squid. Checking them requires suspending
    work on the current request, querying some external source, and
    resuming work when the needed information becomes available. This
    is for example the case for DNS, authenticators or external
    authorization scripts. ACLs can thus be divided in
    FAST ACLs, which do not require going to external
    sources to be fulfilled, and SLOW ACLs, which do.
    Fast ACLs include (as of squid 3.1.0.7):
    all (built-in)
    src
    dstdomain
    dstdom_regex
    myip
    arp
    src_as
    peername
    time
    url_regex
    urlpath_regex
    port
    myport
    myportname
    proto
    method
    http_status {R}
    browser
    referer_regex
    snmp_community
    maxconn
    max_user_ip
    req_mime_type
    req_header
    rep_mime_type {R}
    user_cert
    ca_cert
    Slow ACLs include:
    dst
    dst_as
    srcdomain
    srcdom_regex
    ident
    ident_regex
    proxy_auth
    proxy_auth_regex
    external
    ext_user
    ext_user_regex
    This list may be incomplete or out-of-date. See
    your squid.conf.documented file for details. ACL types
    marked with {R} are reply ACLs, see the dedicated FAQ
    chapter.
    Squid caches the results of ACL lookups whenever
    possible, thus slow ACLs will not always need to go to the external
    data-source.
    Knowing the behaviour of an ACL type is relevant
    because not all ACL matching directives support all kinds of ACLs.
    Some check-points will not suspend the request:
    they allow (or deny) immediately. If a SLOW acl has to be checked,
    and the results of the check are not cached, the corresponding ACL
    result will be as if it didn't match. In other words, such ACL
    types are in general not reliable in all access check clauses.
    
    
