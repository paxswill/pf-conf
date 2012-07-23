# ==============================================================================
#   Copyright 2012 Hannes Juutilainen <hjuutilainen@mac.com>
#   https://github.com/hjuutilainen/pf-conf
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
# ==============================================================================

TITLE = pf-firewall
REVERSE_DOMAIN ?= com.github.hjuutilainen

# Find the tools required to build the packages
PKGBUILD := $(shell which pkgbuild)
PKGBUILD ?= $(shell xcrun -find pkgbuild)
PRODUCTBUILD := $(shell which productbuild)
PRODUCTBUILD ?= $(shell xcrun -find productbuild)
PRODUCTSIGN := $(shell which productsign)
PRODUCTSIGN ?= $(shell xcrun -find productsign)

# Try finding a default code signing identity
SIGNER := $(shell security find-identity -p codesigning -v | grep -o -e '".*"$$')

# M4 input files
M4PREP = "m4_define(\`TITLE',\`$(TITLE)')m4_define(\`REVERSE_DOMAIN',\`$(REVERSE_DOMAIN)')m4_changequote(\`',\`')m4_dnl"
M4FILES := $(subst .in,,$(wildcard *.in))
$(info M4Files: $(M4FILES))
intermediates := $(M4FILES)
%: %.in
	echo $(M4PREP) | cat - $< | m4 -P - > $@

# A canned recipe for staging
stage = mkdir -p $(dir $@) && cp $< $@

# Set up destroot
DESTROOT := destroot

# Stage the launchd property list
$(DESTROOT)/Library/LaunchDaemons/$(REVERSE_DOMAIN).pf.plist: pf.plist
	$(stage)

# Stage the rules
rule := $(DESTROOT)/etc/pf.anchors/$(REVERSE_DOMAIN)
STAGED += $(rule)
$(rule): rules.in
	$(stage)
STAGED += $(rule).macros
$(rule).macros: macros.in
	$(stage)
STAGED += $(rule).d
$(rule).d:
	mkdir -p $@

# Stage the admin commands
# Cancel conflicting builtin rules
.SUFFIXES:
libexec := $(DESTROOT)/usr/local/libexec
cmds := $(addprefix pf-,$(addsuffix .sh,control restart))
staged_libexec := $(addprefix $(libexec)/,$(cmds))
STAGED += $(staged_libexec)
$(staged_libexec): $(libexec)/%: %
	$(stage)
	chmod +x $@

# Stage the installer scripts
SCRIPTSDIR := scripts
scripts := postinstall preinstall
STAGED += $(addprefix $(SCRIPTSDIR)/,$(scripts))
$(addprefix $(SCRIPTSDIR)/,$(scripts)): $(SCRIPTSDIR)/%: %
	$(stage)
	chmod +x $@

destroot: $(STAGED)

# Generate the component package
intermediates += $(TITLE)-component.pkg
$(TITLE)-component.pkg: $(STAGED)
	pkgbuild --root destroot\
		--scripts scripts \
		--identifier $(REVERSE_DOMAIN).$(TITLE) \
		--version 1.0.0 \
		--ownership recommended \
		$(TITLE)-component.pkg

# Generate the final product
$(TITLE).pkg: $(TITLE)-component.pkg distribution.xml
	$(PRODUCTBUILD) \
		--distribution distribution.xml \
		--identifier $(REVERSE_DOMAIN).$(TITLE) \
		--version 1.0.0 \
		$@

# Generate a signed package
%-signed.pkg: %.pkg
	$(PRODUCTSIGN) --sign $(SIGNER) $< $@

clean:
	rm -rf $(DESTROOT) $(SCRIPTSDIR) *.pkg

package: $(TITLE).pkg
signed-package: $(TITLE)-signed.pkg

.PHONY: clean package signed-package destroot
.DEFAULT_GOAL = package
.INTERMEDIATE: $(intermediates)

