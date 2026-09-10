DESTDIR =

SHAREDIR = $(DESTDIR)/usr/share/pct-move-volume-snapshots

.PHONY: install
install:
	install -D -m 0755 src/apply-patches.sh $(SHAREDIR)/apply-patches.sh
	install -d -m 0755 $(SHAREDIR)/patches
	# The canonical series in patches/ also touches the upstream test harness
	# (src/test/), which no installed system has. Ship only the PVE/ hunks.
	for p in patches/*.patch; do \
	    filterdiff --include='*/src/PVE/*' "$$p" > "$(SHAREDIR)/patches/$$(basename $$p)"; \
	done

.PHONY: deb
deb:
	dpkg-buildpackage -b -us -uc
	lintian ../pct-move-volume-snapshots_*_all.deb || true

.PHONY: clean
clean:
	rm -rf debian/pct-move-volume-snapshots debian/.debhelper debian/files debian/debhelper-build-stamp
