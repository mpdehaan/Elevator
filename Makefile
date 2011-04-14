test:
	PERL5LIB=lib:examples:examples/t perl examples/t/SqlFoo.t
	PERL5LIB=lib:examples:examples/t perl examples/t/NoSqlFoo.t

test_graphinator:
	PERL5LIB=lib:examples:examples/t perl examples/t/Graphinator.t
	PERL5LIB=lib:examples:examples/t perl examples/t/GraphinatorPerf.pl

test_neo:
	PERL5LIB=lib:examples:examples/t perl examples/t/Neo.t

