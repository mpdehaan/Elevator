test:
	PERL5LIB=lib:examples:examples/t perl examples/t/SqlFoo.t
	PERL5LIB=lib:examples:examples/t perl examples/t/NoSqlFoo.t

test_graph:
	PERL5LIB=lib:examples:examples/t perl examples/t/Graphinator.t
