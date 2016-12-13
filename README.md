update.ks-ix
============

Це навіть не проект, а так, нацарапано на колінці для однієї конкретної задачі: оновлення route-filter-ів у конфігурації Juniper-а для обміну трафіком у KS-IX.

Що робить?
----------

1.  зчитує route-filter з виводу rtconfig-а для AS-KS-IX;
2.  зчитує активну конфігурацію policy-statement AS-KS-IX з juniper-а;
3.  порівнює їх;
4.  у тому випадку якщо є розбіжності, формує строки для видалення або додання route-filter-ів для policy-statement AS-KS-IX;
5.  комітить нову конфігурацію.

Як користуватися?
-----------------

    $ ./update.ks-ix.pl -rJunRouterIP -uu5ername -p5uperpa55w0rd
