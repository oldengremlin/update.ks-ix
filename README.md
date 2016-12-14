update.ks-ix
============

Це навіть не проект, а так, нацарапано на колінці для однієї конкретної задачі: оновлення route-filter-ів у конфігурації Juniper-а для обміну трафіком у [KS-IX](http://ix.ks.ua/).

Що робить?
----------

1.  зчитує route-filter з виводу rtconfig-а для [AS-KS-IX](http://ix.ks.ua/policy.html);
2.  зчитує активну конфігурацію policy-statement [AS-KS-IX](http://ix.ks.ua/policy.html) з juniper-а;
3.  порівнює їх;
4.  у тому випадку якщо є розбіжності, формує строки для видалення або додання route-filter-ів для policy-statement AS-KS-IX;
5.  комітить нову конфігурацію.

Як користуватися?
-----------------

    $ ./update.ks-ix.pl -rJunRouterIP -uu5ername -p5uperpa55w0rd

Трішки про конфігурацію policy-options на Juniper-і
---------------------------------------------------

    policy-statement AS-KS-IX {
        term prefixes {
            from {
                community AS-KS-IX;
                route-filter 41.76.232.0/21 exact accept;
                … skip …
                route-filter 195.38.16.0/23 exact accept;
            }
            then {
                local-preference 300;
                accept;
            }
        }
        term next {
            then next policy;
        }
    }

    policy-statement REJECT {
        then reject;
    }

    community AS-KS-IX members 8695:64000;

### …та protocols bgp group uplinks

    neighbor A.A.A.A {
        description KS-IX;
        local-address B.B.B.B;
        import [ AS-KS-IX REJECT ];
        family inet {
            any {
                accepted-prefix-limit {
                    maximum 5000;
                    teardown 85 idle-timeout 2;
                }
            }
        }
        export [ NETS-EXPORT REJECT ];
        remove-private;
        peer-as 8695;
    }
