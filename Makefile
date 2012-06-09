.PHONY: doc

REBAR=$(shell which rebar || echo ./rebar)

all: compile escriptize

escriptize: compile
	@$(REBAR) escriptize

compile:
	@$(REBAR) compile

clean:
	@$(REBAR) clean
