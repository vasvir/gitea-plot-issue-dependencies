RMDIR = rm -rf

GRAPHVIZ_RATIO_MONITOR_4_3 = 0.7500
GRAPHVIZ_RATIO_MONITOR_16_9 = 0.5625
GRAPHVIZ_RATIO_A4_PORTRAIT = 1.5397
GRAPHVIZ_RATIO_A4_LANDSCAPE = 0.6495
GRAPHVIZ_RATIO ?= $(GRAPHVIZ_RATIO_A4_LANDSCAPE)
GRAPHVIZ ?= dot -Gratio=$(GRAPHVIZ_RATIO)
GRAPHVIZ ?= sfdp -Gratio=$(GRAPHVIZ_RATIO) -Goverlap=false -Gconcentrate=true -Gsplines=true

.ONESHELL:

.PHONY : all clean

ifdef ISSUE
all: gitea-issue-$(ISSUE).svg

clean:
	$(RM) gitea-issues.data gitea-issue-$(ISSUE).dot gitea-issue-$(ISSUE).svg gitea-issue-$(ISSUE).png
else
all: gitea-issues.svg

clean:
	$(RM) gitea-issues.data gitea-issues.dot gitea-issues.svg gitea-issues.png
endif

gitea-issues.data:
	@ssh $(HOST) 'mysql gitea -Ne "SELECT i1.\`index\`, i1.name, i1.is_closed, i2.\`index\`, i2.name, i2.is_closed FROM issue_dependency d, issue i1, issue i2 WHERE d.issue_id = i1.id AND d.dependency_id = i2.id;"' > $@;

gitea-issues.dot: gitea-issues.data
	@cat $< | awk -vFS='\t' 'BEGIN {
		print "digraph issues {";
		print "  label=\"All Connected Issues\"";
		print "  URL=\"$(BASE_URL)\" target=_blank";
		print "";
	} {
		id1 = $$1;
		name1 = $$2;
		closed1 = $$3;
		id2 = $$4;
		name2 = $$5;
		closed2 = $$6;
		nodes[id1] = name1;
		nodesClosed[id1] = closed1;
		nodes[id2] = name2;
		nodesClosed[id2] = closed2;
		targets[id1] = name1;
		dependencies[id2] = name2;
		deps[id2][id1] = 1;
		#print $$0;
	} END {
		for (i in dependencies) {
			delete targets[i];
		}

		for (i in nodes) {
			if (nodesClosed[i]) {
				color = "fontcolor=white fillcolor=green";
			} else {
				color = (i in dependencies) ? "fontcolor=white fillcolor=red" : "fillcolor=white";
			}
			print "  \"" nodes[i] "\" [style=filled " color " URL=\"$(BASE_URL)/" i "\" target=_blank]";
		}
		print "";

		for (i in deps) {
			for (j in deps[i]) {
				print "  \"" nodes[i] "\" -> \"" nodes[j] "\"";
			}
		}

		print "}";
	}' > $@;

gitea-issue-$(ISSUE).dot: gitea-issues.data
	@cat $< | awk -vFS='\t' '
	function print_array(label, a,      i) {
		printf(label ": ");
		for (i in a) {
			printf(i ":" a[i] ", ");
		}
		print "";
	}

	function get_direct_dependencies(a, offset, rdeps, d,    i, l, n, k) {
		l = length(a);
		#print "# get_direct_dependencies: length:", l, "offset: ", offset;
		#print_array("# get_direct_dependencies: d ", d);
		k = 0;
		for (i = offset; i < l; i++) {
			for (j in rdeps[a[i]]) {
				d[k++] = j;
			}
		}
	}

	# find all dependencies of a specific set of issues
	function get_dependencies(a, offset, rdeps,      d, k, l, i) {
		#print_array("# get_dependencies: for a ", a);
		split("", d);
		get_direct_dependencies(a, offset, rdeps, d);
		#print_array("# get_dependencies: New direct depedancies", d);

		k = 0;
		l = length(a);
		for (i in d) {
			a[l + k++] = d[i];
		}
		if (!length(d))
			return;

		get_dependencies(a, l, rdeps);
	}

	BEGIN {
		print "digraph issues {";
		print "  label=\"Issue $(ISSUE)\"";
		print "  URL=\"$(BASE_URL)/" $(ISSUE) "\" target=_blank";
		print "";
	} {
		id1 = $$1;
		name1 = $$2;
		closed1 = $$3;
		id2 = $$4;
		name2 = $$5;
		closed2 = $$6;
		nodes[id1] = name1;
		nodesClosed[id1] = closed1;
		nodes[id2] = name2;
		nodesClosed[id2] = closed2;
		if (id1 == $(ISSUE))
			targets[id1] = name1;
		dependencies[id2] = name2;
		deps[id2][id1] = 1;
		rdeps[id1][id2] = 1;
		#print $$0;
	} END {
		tokeep_a[0] = $(ISSUE);
		get_dependencies(tokeep_a, 0, rdeps);
		#print_array("# tokeep_a", tokeep_a);

		for (i in tokeep_a) {
			tokeep[tokeep_a[i]] = 1;
		}

		# now delete all nodes not in the dependency tree
		for (i in nodes) {
			#print "# checking node " i, nodes[i];
			if (i in tokeep) {
				continue;
			}
			#print "# deleting node " i, nodes[i];
			delete nodes[i];
		}

		for (i in nodes) {
			if (nodesClosed[i]) {
				color = "fontcolor=white fillcolor=green";
			} else {
				color = (i in dependencies) ? "fontcolor=white fillcolor=red" : "fillcolor=white";
			}
			print "  \"" nodes[i] "\" [style=filled " color " URL=\"$(BASE_URL)/" i "\" target=_blank]";
		}
		print "";

		for (i in deps) {
			for (j in deps[i]) {
				if (nodes[i] && nodes[j]) {
					print "  \"" nodes[i] "\" -> \"" nodes[j] "\"";
				}
			}
		}

		print "}";
	}' > $@;

gitea-issues.svg: gitea-issues.dot
	$(GRAPHVIZ) -Tsvg -o $@ < $<;

gitea-issue-$(ISSUE).svg: gitea-issue-$(ISSUE).dot
	$(GRAPHVIZ) -Tsvg -o $@ < $<;

gitea-issues.png: gitea-issues.dot
	$(GRAPHVIZ) -Tpng -o $@ < $<;

gitea-issue-$(ISSUE).png: gitea-issue-$(ISSUE).dot
	$(GRAPHVIZ) -Tpng -o $@ < $<;
