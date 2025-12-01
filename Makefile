# ----------------------------
# group number {GROUP_NUMBER}
# {NOMA1} : {STUDENT1}
# {NOMA2} : {STUDENT2}
# ----------------------------

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    OZC = /Applications/Mozart2.app/Contents/Resources/bin/ozc
    OZENGINE = /Applications/Mozart2.app/Contents/Resources/bin/ozengine
else
    OZC = ozc
    OZENGINE = ozengine
endif

all: compile run

compile:
	$(OZC) -c Input.oz -o "compiled/Input.ozf"
	$(OZC) -c AgentManager.oz -o "compiled/AgentManager.ozf"
	$(OZC) -c AgentBlank.oz -o "compiled/AgentBlank.ozf"
	$(OZC) -c Graphics.oz -o "compiled/Graphics.ozf"
	$(OZC) -c Main.oz -o "compiled/Main.ozf"
run:
	$(OZC) -c Input.oz -o "compiled/Input.ozf"
	$(OZENGINE) compiled/Main.ozf