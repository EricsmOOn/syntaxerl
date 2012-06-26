-module(syntaxerl_utils).
-author("Dmitry Klionsky <dm.klionsky@gmail.com>").

-export([
	incls_ebins_opts/1,
	error_description/1,
	print_issues/2
]).

-include("issues_spec.hrl").

%% API

-spec incls_ebins_opts(FileName::file:filename()) ->
	{InclDirs::[file:name()], EbinDirs::[file:name()], ErlcOpts::[term()]}.
incls_ebins_opts(FileName) ->
	AbsFileName = filename:absname(FileName),
	BaseDir = filename:dirname(filename:dirname(AbsFileName)),

	DepsDirs = deps_dirs(BaseDir),
	ErlcOpts = erlc_opts(BaseDir),

	{_, EbinDirs} = lists:mapfoldr(fun(Dir, Acc) -> {0, filelib:wildcard(Dir ++ "/*/ebin") ++ Acc} end, [], DepsDirs),
	IncludeDirs = lists:map(fun(Dir) -> {i, Dir} end, DepsDirs),
	{IncludeDirs, EbinDirs, ErlcOpts}.

-spec deps_dirs(BaseDir::file:name()) -> [Dir::file:name()].
deps_dirs(BaseDir) ->
	OtpStdDirs = absdirs(BaseDir, ["./include", "./deps"]),
	DepsDirs =
		case rebar_deps_dirs(BaseDir) of
			{ok, RebarDepsDirs} ->
				RebarDepsDirs;
			{error, bad_format} ->
				[]; % nothing to do. fix your config file. :(
			{error, not_found} ->
				% sinan, Emakefile, ...
				[]
		end,
	UniqDirs = uniq(OtpStdDirs ++ DepsDirs),
	lists:map(fun(Dir) -> filename:join(BaseDir, Dir) end, UniqDirs).

-spec erlc_opts(BaseDir::file:name()) -> [Option::term()].
erlc_opts(BaseDir) ->
	DefaultErlcOpts = [
		strong_validation,

		{warn_format, 1},
		warn_export_vars,
		warn_shadow_vars,
		warn_obsolete_guard,
		warn_deprecated_function,
		warn_exported_vars,
		warn_bif_clash,
		warn_unused_import,
		warn_unused_function,
		warn_unused_variable,
		warn_unused_vars,
		warn_unused_record,

		return_errors,
		return_warnings
	],
	ErlcOpts =
		case rebar_erlc_opts(BaseDir) of
			{ok, RebarErlcOpts} ->
				RebarErlcOpts;
			{error, bad_format} ->
				[]; % nothing to do. fix your config file. :(
			{error, not_found} ->
				% sinan, Emakefile, ...
				[]
		end,
	uniq(DefaultErlcOpts ++ ErlcOpts).

%% the `file:format_error' returns the error description in the `line: description' format.
%% here only the `description' is returned.
-spec error_description({Line::integer(), Mod::module(), Term::term()}) -> string().
error_description(Error) ->
	tl(lists:dropwhile(fun(C) -> C =/= 32 end, file:format_error(Error))).

-spec print_issues(FileName::file:filename(), Issues::[issue()]) -> ok.
print_issues(_FileName, []) ->
	ok;
print_issues(FileName, [Issue | Issues]) ->
	print_issue(FileName, Issue),
	print_issues(FileName, Issues).

print_issue(FileName, {warning, Line, Description}) ->
	io:format("~s:~p: warning: ~s~n", [FileName, Line, Description]);
print_issue(FileName, {error, Description}) ->
	io:format("~s:~s~n", [FileName, Description]);
print_issue(FileName, {error, Line, Description}) ->
	io:format("~s:~p: ~s~n", [FileName, Line, Description]).

%% Internal

rebar_deps_dirs("/") ->
	{error, not_found};
rebar_deps_dirs(BaseDir) ->
	RebarConfig = filename:join(BaseDir, "rebar.config"),
	case filelib:is_file(RebarConfig) of
		true ->
			case file:consult(RebarConfig) of
				{ok, Terms} ->
					LibDirs = proplists:get_value(lib_dirs, Terms, []),
					DepsDir = proplists:get_value(deps_dir, Terms, ["deps"]),
					%% recursively try to find configs in parents directory.
					case rebar_deps_dirs(filename:dirname(BaseDir)) of
						{ok, ParentDirs} ->
							{ok, absdirs(BaseDir, uniq(LibDirs ++ DepsDir ++ ParentDirs))};
						{error, _} ->
							{ok, absdirs(BaseDir, uniq(LibDirs ++ DepsDir))}
					end;
				{error, _} ->
		            {error, bad_format}
			end;
		false ->
			rebar_deps_dirs(filename:dirname(BaseDir))
	end.

rebar_erlc_opts("/") ->
	{error, not_found};
rebar_erlc_opts(BaseDir) ->
	RebarConfig = filename:join(BaseDir, "rebar.config"),
	case filelib:is_file(RebarConfig) of
		true ->
			case file:consult(RebarConfig) of
				{ok, Terms} ->
					ErlcOpts = proplists:get_value(erl_opts, Terms, []),
					%% recursively try to find configs in parents directory.
					case rebar_erlc_opts(filename:dirname(BaseDir)) of
						{ok, ParentErlcOpts} ->
							{ok, uniq(ErlcOpts ++ ParentErlcOpts)};
						{error, _} ->
							{ok, uniq(ErlcOpts)}
					end;
				{error, _} ->
		            {error, bad_format}
			end;
		false ->
			rebar_erlc_opts(filename:dirname(BaseDir))
	end.

uniq(List) ->
	sets:to_list(sets:from_list(List)).

absdirs(BaseDir, RelativeDirs) ->
	lists:map(fun(Dir) -> filename:join(BaseDir, Dir) end, RelativeDirs).
