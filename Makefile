#!/usr/bin/make -rRsf

SHELL=/bin/bash -o pipefail

#USAGE:
#
#	make
#

MAKEDIR := $(dir $(firstword $(MAKEFILE_LIST)))
DIR := ${CURDIR}
CONDAROOT = ${DIR}/software/anaconda/install/
orthopath := $(shell ls ${DIR}/software/OrthoFinder/orthofinder/orthofuser.py 2>/dev/null)
orthufuserversion = $(shell orthofuser.py --help | grep "OrthoFinder version" | awk '{print $$3}')
transrate := $(shell ls ${DIR}/software/orp-transrate/transrate 2>/dev/null)
transabysspath := $(shell which ${DIR}/software/transabyss/transabyss 2>/dev/null)
transabyssversion = $(shell conda ${DIR}/software/anaconda/install/bin/activate orp 2>/dev/null; transabyss --version 2>/dev/null; conda deactivate 2> /dev/null)
diamond_data := $(shell ls ${DIR}/software/diamond/uniprot_sprot.fasta 2>/dev/null)
busco_data := $(shell ls ${DIR}/busco_dbs/eukaryota_odb10 2>/dev/null)
conda := $(shell conda info 2>/dev/null)
orp := $(shell ${DIR}/software/anaconda/install/bin/conda info --envs | grep orp 2>/dev/null)
VERSION := ${shell cat  ${MAKEDIR}version.txt}

all: setup conda orp orthofuser transrate transabyss diamond_data busco_data postscript

.DELETE_ON_ERROR:

setup:
	@mkdir -p ${DIR}/shared
	@mkdir -p ${DIR}/software/anaconda
	@mkdir -p ${DIR}/software/diamond

conda:setup
ifdef conda
else
	cd ${DIR}/software/anaconda && curl -LO https://repo.anaconda.com/archive/Anaconda3-2019.10-Linux-x86_64.sh
	cd ${DIR}/software/anaconda && bash Anaconda3-2019.10-Linux-x86_64.sh -b -p install/
	echo ". ${DIR}/software/anaconda/install/etc/profile.d/conda.sh" >> ~/.bashrc;
	source ~/.bashrc;
endif

orp:orp_env.yml conda setup
ifdef orp
else
	( \
				source ${DIR}/software/anaconda/install/etc/profile.d/conda.sh; \
				conda activate; \
				conda update -y -n base conda; \
				conda env create -f ${DIR}/orp_env.yml ; \
				conda deactivate; \
  )
	@echo PATH=\$$PATH:${DIR}/software/anaconda/install/bin > pathfile;
endif

transabyss:
ifdef transabysspath
ifeq ($(transabyssversion),2.0.1)
	@echo "TransABySS is already installed"
else
	@echo "version ${transabyssversion}"
	@echo "TransABySS is installed, but not the right version"
	cd ${DIR}/software/transabyss && git pull
endif
else
	cd ${DIR}/software/ && git clone https://github.com/bcgsc/transabyss.git
	@echo PATH=\$$PATH:${DIR}/software/transabyss >> pathfile
endif

diamond_data:conda
ifdef diamond_data
	@echo "diamond_data is already installed"
else
	 cd ${DIR}/software/diamond && curl -LO ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz && gzip -d uniprot_sprot.fasta.gz
	 cd ${DIR}/software/diamond && ${DIR}/software/anaconda/install/envs/orp/bin/diamond makedb --in uniprot_sprot.fasta -d swissprot
endif

busco_data:conda
ifdef busco_data
else
	mkdir ${DIR}/busco_dbs && cd ${DIR}/busco_dbs
	cd ${DIR}/busco_dbs && wget https://busco-data.ezlab.org/v4/data/lineages/eukaryota_odb10.2019-11-20.tar.gz && tar -zxf eukaryota_odb10.2019-11-20.tar.gz
endif

transrate:
ifdef transrate
else
	cd ${DIR}/software && tar -zxf orp-transrate.tar.gz
	@echo PATH=\$$PATH:${DIR}/software/orp-transrate >> pathfile
endif

orthofuser:
ifdef orthopath
ifeq ($(orthufuserversion),2.3.9)
	@echo "orthofuser right version is already installed"
else
	@echo "version ${orthufuserversion}"
	@echo "orthofuser is installed, but not the right version"
	cd ${DIR}/software/OrthoFinder/ && git pull
endif
else
	@echo "orthofuser is not installed and needs to be installed"
	cd ${DIR}/software && git clone https://github.com/macmanes-lab/OrthoFinder.git
	@echo PATH=\$$PATH:${DIR}/software/OrthoFinder/ >> pathfile
endif

postscript: setup orp diamond_data busco_data orthofuser conda transrate
	@if [ -f pathfile ]; then\
		printf "\n\n*** The following location(s), if any print, need to be added to your PATH ***";\
		printf "\n*** They will be automatically to your ~/.profile or ~/.bash_profile ***\n\n";\
		cat pathfile;\
		cat pathfile >> ~/.profile;\
		cat pathfile >> ~/.bash_profile;\
		export PATH=$$PATH:$$(cat pathfile);\
		printf "\n\n\n";\
		printf "\n*** type ``source ~/.profile`` to complete the install ***\n\n";\
	fi

clean:
	${DIR}/software/anaconda/install/bin/conda remove -y --name orp --all
	rm -fr ${DIR}/software/anaconda/install
	rm -fr ${DIR}/software/OrthoFinder/
	rm -fr ${DIR}/software/orp-transrate
	rm -fr ${DIR}/software/transabyss
	rm -fr ${DIR}/software/anaconda/
	rm -fr ${DIR}/pathfile
