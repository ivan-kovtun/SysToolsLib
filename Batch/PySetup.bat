<# :# PowerShell comment block protecting the batch section
@echo off & goto :init_batch
:#----------------------------------------------------------------------------#
:#                                                                            #
:#  File name       PySetup.bat                                               #
:#                                                                            #
:#  Description     Configure Windows for running Python scripts              #
:#                                                                            #
:#  Notes           Allows switching between multiple versions of Python.     #
:#                                                                            #
:#                  Designed as a diagnostics tool. The default action is to  #
:#                  analyse the current configuration, and suggest changes.   #
:#                                                                            #
:#                  The -v option shows which commands are used to get infos. #
:#                                                                            #
:#  History                                                                   #
:#   2017-01-13 JFL Created this script based on tclsh.bat.                   #
:#   2017-01-24 JFL Added steps for the InstallPath and PythonPath setup.     #
:#                  Always display test results, even in setup mode.	      #
:#   2017-04-14 JFL Added a check of Explorer File Extensions User Choice.    #
:#                                                                            #
:#         � Copyright 2017 Hewlett Packard Enterprise Development LP         #
:# Licensed under the Apache 2.0 license  www.apache.org/licenses/LICENSE-2.0 #
:#----------------------------------------------------------------------------#

:init_batch
setlocal EnableExtensions EnableDelayedExpansion
set "VERSION=2017-04-14"
set "SCRIPT=%~nx0"				&:# Script name
set "SPATH=%~dp0" & set "SPATH=!SPATH:~0,-1!"	&:# Script path, without the trailing \
set "SFULL=%~f0"				&:# Script full pathname
set ^"ARG0=%0^"					&:# Script invokation name
set ^"ARGS=%*^"					&:# Argument line

:# Mechanism for calling subroutines in a second instance of a script, from its main instance.
:# Done by (%XCALL% :label [arguments]), with XCALL defined in the Call module below.
if '%1'=='-call' !ARGS:~1!& exit /b

:# Initialize the most commonly used library components.
call :Library.Init

goto Main

:#----------------------------------------------------------------------------#
:#                                                                            #
:#  Function	    Library.Init					      #
:#                                                                            #
:#  Description     Initialize the most commonly used library components      #
:#                                                                            #
:#----------------------------------------------------------------------------#

:Library.Init
:# Initialize this library modules definitions.
:# Each one depends on the preceding ones, so if you need one, you need all the preceding ones as well.
call :Call.Init			&:# Function calls and argument extraction
call :Macro.Init		&:# Inline macros generation
call :Debug.Init		&:# Debug routines
call :Exec.Init			&:# Conditional execution routines
call :Echo.Color.Init

:# FOREACHLINE macro. (Changes the delimiter to none to catch the whole lines.)
set FOREACHLINE=for /f "delims="

:# HOME variable. For analogy with Unix systems.
if not defined HOME set "HOME=%HOMEDRIVE%%HOMEPATH%"

goto :eof

:#----------------------------------------------------------------------------#
:#                                                                            #
:#  Module	    Call						      #
:#                                                                            #
:#  Description     Manage function calls and argument extraction             #
:#                                                                            #
:#  Functions	    PopArg          Pop the first argument from %ARGS% into   #
:#				     %ARG% and %"ARG"%			      #
:#		    PopSimpleArg    Simpler and faster version, incompatible  #
:#                                   with ! or ^ characters in ARG values.    #
:#		    Prep2ExpandVars Prepare variables to return from the      #
:#		 		    local scope (with expansion on or off)    #
:#				    to a parent scope with expansion on.      #
:#		    PrepArgVars     Prepare variables containing pathnames    #
:#				    that will be passed as arguments.	      #
:#                                                                            #
:#  Macros	    %POPARG%        Pop one argument using :PopArg            #
:#                  %POPSARG%       Pop one argument using :PopSimpleArg      #
:#                  %LCALL%         Call a routine in this library, either    #
:#                                   locally, or from an outside script.      #
:#                  %XCALL%         Call an outside script routine, from      #
:#                                   another instance of that outside script. #
:#                  %XCALL@%        Idem, but with all args stored in one var.#
:#                                                                            #
:#  Variables	    %ARG%           The unquoted argument                     #
:#                  %"ARG"%         The actual argument, possibly quoted      #
:#                  %ARGS%	    Remaining command line arguments          #
:#                                                                            #
:#                  %CR%            An ASCII Carrier Return character '\x0D'  #
:#                  %LF%            An ASCII Line Feed character '\x0A'       #
:#                  %BS%            An ASCII Back Space character '\x08'      #
:#                  %FF%            An ASCII Form Feed character '\x0C'       #
:#                                                                            #
:#  Notes 	    PopArg works around the defect of the shift command,      #
:#                  which pops the first argument from the %* list, but does  #
:#                  not remove it from %*.                                    #
:#                  Also works around another defect with tricky characters   #
:#                  like ! or ^ being lost when variable expansion is on.     #
:#                                                                            #
:#                  Important: The performance of this routine is much better #
:#                  when invoked with variable expansion disabled. This is    #
:#                  due to the complex processing done to avoid issues with   #
:#                  tricky characters like ! or ^ when expansion is enabled.  #
:#                  If you're sure that NONE of the arguments contain such    #
:#                  tricky characters, then call :PopSimpleArg.               #
:#                                                                            #
:#                  Uses an inner call to make sure the argument parsing is   #
:#                  done by the actual cmd.exe parser. This guaranties that   #
:#                  arguments are split exactly as shift would have done.     #
:#                                                                            #
:#                  But call itself has a quirk, which requires a convoluted  #
:#                  workaround to process the /? argument.                    #
:#                                                                            #
:#                  Known limitation: After using :PopArg, all consecutive    #
:#                  argument separators in %ARGS% are replaced by one space.  #
:#                  For example: "A==B" becomes "A B"                         #
:#                  This does not change the result of subsequent calls to    #
:#                  :PopArg, but this prevents from using the tail itself as  #
:#                  an argument. => Do not use :PopArg to get :Exec args!     #
:#                                                                            #
:#                  To do: Detect if the last arg has mismatched quotes, and  #
:#                  if it does, append one.                                   #
:#                  Right now such mismatched quotes will cause an error here.#
:#                  Do not work around this error to only pass back the bad   #
:#                  argument, as this will only cause more errors further down#
:#                                                                            #
:#  History                                                                   #
:#   2015-04-03 JFL Bug fix: Quoted args with an & inside failed to be poped. #
:#   2015-07-06 JFL Bug fix: Call quirk prevented inner call from popping /?. #
:#   2016-11-18 JFL Fixed popping arguments containing % characters.          #
:#   2016-11-21 JFL Fixed popping quoted arguments containing &|<> characters.#
:#   2016-11-22 JFL Fixed popping arguments containing ^ characters.          #
:#   2016-11-24 JFL Updated %POPARG% to work with trick characters ! and ^ in #
:#                  delayed expansion mode. The old and faster version is now #
:#		    called %POPSARG%.                                         #
:#		    Added routine :Prep2ExpandVars allowing to pass any       #
:#		    tricky string across call or endlocal barriers.           #
:#   2016-12-01 JFL Added a %FF% Form Feed character variable.                #
:#                                                                            #
:#----------------------------------------------------------------------------#

call :Call.Init
goto Call.end

:Call.Init
if not defined LCALL set "LCALL=call"	&:# Macro to call functions in this library
set "POPARG=%LCALL% :PopArg"
set "POPSARG=%LCALL% :PopSimpleArg"

:# Mechanism for calling subroutines in a second external instance of the top script.
set ^"XCALL=call "!ARG0!" -call^"	&:# This is the top script's (or this lib's if called directly) ARG0
set ^"XCALL@=!XCALL! :CallVar^"		&:# Indirect call, with the label and arguments in a variable

:# Define a LF variable containing a Line Feed ('\x0A')
set LF=^
%# The two blank lines here are necessary. #%
%# The two blank lines here are necessary. #%

:# Define a CR variable containing a Carriage Return ('\x0D')
for /f %%a in ('copy /Z %COMSPEC% nul') do set "CR=%%a"

:# Define a BS variable containing a BackSpace ('\x08')
:# Use prompt to store a  backspace+space+backspace into a DEL variable.
for /F "tokens=1 delims=#" %%a in ('"prompt #$H# & echo on & for %%b in (1) do rem"') do set "DEL=%%a"
:# Then extract the first backspace
set "BS=%DEL:~0,1%"

:# Define a FF variable containing a Form Feed ('\x0C')
for /f %%A in ('cls') do set "FF=%%A"

:# Define variables for problematic characters, that cause parsing issues.
:# Use the ASCII control character name, or the html entity name.
:# Warning: The excl and hat characters need different quoting depending on context.
set  "DEBUG.percnt=%%"	&:# One percent sign
set  "DEBUG.excl=^!"	&:# One exclamation mark
set  "DEBUG.hat=^"	&:# One caret, aka. circumflex accent, or hat sign
set ^"DEBUG.quot=""	&:# One double quote
set  "DEBUG.apos='"	&:# One apostrophe
set  "DEBUG.amp=&"	&:# One ampersand
set  "DEBUG.vert=|"	&:# One vertical bar
set  "DEBUG.gt=>"	&:# One greater than sign
set  "DEBUG.lt=<"	&:# One less than sign
set  "DEBUG.lpar=("	&:# One left parenthesis
set  "DEBUG.rpar=)"	&:# One right parenthesis
set  "DEBUG.lbrack=["	&:# One left bracket
set  "DEBUG.rbrack=]"	&:# One right bracket
set  "DEBUG.sp= "	&:# One space
set  "DEBUG.tab=	"	&:# One tabulation
set  "DEBUG.quest=?"	&:# One question mark
set  "DEBUG.ast=*"	&:# One asterisk
set  "DEBUG.cr=!CR!"	&:# One carrier return
set  "DEBUG.lf=!LF!"	&:# One line feed
set  "DEBUG.bs=!BS!"	&:# One backspace
set  "DEBUG.ff=!FF!"	&:# One form feed
goto :eof

:PopArg
if "!!"=="" goto :PopArg.Eon
:PopArg.Eoff
:PopSimpleArg :# Will corrupt result if expansion is on and ARG contains ^ or ! characters.
:# Gotcha: The call parser first scans its command line for an unquoted /?.
:# If it finds one anywhere on the command line, then it ignores the target label and displays call help.
:# To work around that, we initialize %ARG% and %"ARG"% with an impossible combination of values.
set "ARG=Yes"
set ""ARG"=No"
set "PopArg.ARGS="
if defined ARGS (
  setlocal EnableDelayedExpansion
  for /f "delims=" %%a in ("!ARGS:%%=%%%%!") do endlocal & set ^"PopArg.ARGS=%%a^"
)
call :PopArg.Helper %PopArg.ARGS% >NUL 2>NUL &:# Output redirections ensure the call help is not actually output.
:# Finding that impossible combination now is proof that the call was not executed.
:# In this case, try again with the /? quoted, to prevent the call parser from processing it.
:# Note that we can not systematically do this /? enquoting, else it's "/?" that would break the call.
if "%ARG%"=="Yes" if [%"ARG"%]==[No] call :PopArg.Helper %PopArg.ARGS:/?="/?"%
set "PopArg.ARGS="
goto :eof
:PopArg.Helper
set "ARG=%~1"		&:# Remove quotes from the argument
set ^""ARG"=%1^"	&:# The same with quotes, if any, should we need them
if defined ARG set "ARG=%ARG:^^=^%"
if defined "ARG" set ^""ARG"=%"ARG":^^=^%^"
:# Rebuild the tail of the argument line, as shift does not do it
:# Never quote the set ARGS command, else some complex quoted strings break
set ARGS=%2
:PopArg.GetNext
shift
if defined ARGS set ^"ARGS=%ARGS:^^=^%^"
if [%2]==[] goto :eof
:# Leave quotes in the tail of the argument line
set ARGS=%ARGS% %2
goto :PopArg.GetNext

:PopArg.Eon
setlocal DisableDelayedExpansion
call :PopArg
call :Prep2ExpandVars ARG ^""ARG"^" ARGS
setlocal EnableDelayedExpansion
for /f %%a in ("-!ARG!") do for /f %%b in ("-!"ARG"!") do for /f %%c in ("-!ARGS!") do (
  endlocal
  endlocal
  set "ARG=%%a"
  set "ARG=!ARG:~1!"
  set ^""ARG"=%%b^"
  set ^""ARG"=!"ARG":~1!^"
  set ^"ARGS=%%c^"
  set "ARGS=!ARGS:~1!"
)
goto :eof

:# Prepare variables to return from the local scope (with expansion on or off) to a parent scope with expansion on
:Prep2ExpandVars VAR [VAR ...]
if "!!"=="" goto :Prep2ExpandVars.Eon
:Prep2ExpandVars.Eoff	:# The local scope has expansion off
setlocal EnableDelayedExpansion
set "VALUE=!%~1!"
call :Prep2ExpandVars.Eon VALUE
endlocal & set "%~1=%VALUE%"
if not [%2]==[] shift & goto :Prep2ExpandVars.Eoff
goto :eof

:# Prepare variables, assuming the local scope itself has expansion on
:Prep2ExpandVars.Eon VAR [VAR ...]
if defined %1 (
  for %%e in (sp tab cr lf quot amp vert lt gt hat percnt) do ( :# Encode named character entities
    for %%c in ("!DEBUG.%%e!") do (
      set "%~1=!%~1:%%~c= DEBUG.%%e !"
    )
  )
  call set "%~1=%%%~1:^!= DEBUG.excl %%" 	& rem :# Encode exclamation points
  call set "%~1=%%%~1: =^!%%"			& rem :# Encode final expandable entities
)
if not [%2]==[] shift & goto :Prep2ExpandVars.Eon
goto :eof

:# Prepare variables containing pathnames that will be passed as "arguments"
:PrepArgVars
set "%~1=!%~1:%%=%%%%!"				&:# Escape percent signs
if not [%2]==[] shift & goto :PrepArgVars
goto :eof

:# Indirect call, with the label and arguments in a variable
:CallVar CMDVAR
call !%1:%%=%%%%!
exit /b

:Call.end

:#----------------------------------------------------------------------------#
:#                                                                            #
:#  Module          Macro						      #
:#                                                                            #
:#  Description     Tools for defining inline functions,                      #
:#                  also known as macros by analogy with Unix shells macros   #
:#                                                                            #
:#  Macros          %MACRO%         Define the prolog code of a macro         #
:#                  %/MACRO%        Define the epilog code of a macro         #
:#                                                                            #
:#  Variables       %LF1%           A Line Feed ASCII character '\x0A'        #
:#                  %LF2%           Generates a LF when expanded twice        #
:#                  %LF3%           Generates a LF when expanded 3 times      #
:#                                  Etc...                                    #
:#                  %\n%            Macro command line separator              #
:#                                                                            #
:#  Notes           The principle is to define a variable containing the      #
:#                  complete body of a function, like this:                   #
:#                  set $macro=for %%$ in (1 2) do if %%$==2 ( %\n%           #
:#                    :# Define the body of your macro here %\n%              #
:#                    :# Then return the result to the caller %\n%            #
:#                    for /f "delims=" %%r in ('echo.%!%RETVAL%!%') do ( %\n% #
:#                      endlocal %&% set "RETVAL=%%~r" %\n%                   #
:#                    ) %\n%                                                  #
:#                  ) else setlocal enableDelayedExpansion %&% set ARGS=      #
:#                                                                            #
:#                  It is then invoked just like an external command:         #
:#                  %$macro% ARG1 ARG2 ...                                    #
:#                                                                            #
:#                  The ideas that make all this possible were published on   #
:#                  the dostips.com web site, in multiple messages exchanged  #
:#                  by community experts.                                     #
:#                  By convention on the dostips.com web site, macro names    #
:#                  begin by a $ character; And the %\n% variable ends lines. #
:#                  The other variables are mine.                             #
:#                                                                            #
:#                  The use of a for loop executed twice, is critical for     #
:#                  allowing to place arguments behind the macro.             #
:#                  The first loop executes only the tail line, which defines #
:#                  the arguments; The second loop executes the main body of  #
:#                  the macro, which processes the arguments, and returns the #
:#                  result(s).                                                #
:#                  To improve the readability of macros, replace the code in #
:#                  the first line by %MACRO%, and the code in the last line  #
:#                  by %/MACRO%                                               #
:#                                                                            #
:#                  The use of the Line Feed character as command separator   #
:#                  within macros is a clever trick, that helps debugging,    #
:#                  but it is not necessary for macros to work.               #
:#                  This helps debugging, because this allows to output the   #
:#                  macro definition as a structured string spanning several  #
:#                  lines, looking exactly like a normal function with one    #
:#                  instruction per line.                                     #
:#                  But it would be equally possible to define macros using   #
:#                  the documented & character as command separator.          #
:#                                                                            #
:#                  Limitations:                                              #
:#                  - A macro cannot call another macro.                      #
:#                    (This would require escaping all control characters in  #
:#                     the sub-macro, so that they survive an additional      #
:#                     level of expansion.)                                   #
:#                                                                            #
:#  History                                                                   #
:#   2015-04-15 JFL Initial version, based on dostips.com samples, with       #
:#                  changes so that they work with DelayedExpansion on.       #
:#   2015-11-27 JFL Added a primitive macro debugging capability.             #
:#                                                                            #
:#----------------------------------------------------------------------------#

call :Macro.Init
goto :Macro.End

:Macro.Init
:# LF generator variables, that become an LF after N expansions
:# %LF1% == %LF% ; %LF2% == To expand twice ; %LF3% == To expand 3 times ; Etc
:# Starting with LF2, the right # of ^ doubles on every line,
:# and the left # of ^ is 3 times the right # of ^.
set ^"LF1=^%LF%%LF%"
set ^"LF2=^^^%LF1%%LF1%^%LF1%%LF1%"
set ^"LF3=^^^^^^%LF2%%LF2%^^%LF2%%LF2%"
set ^"LF4=^^^^^^^^^^^^%LF3%%LF3%^^^^%LF3%%LF3%"
set ^"LF5=^^^^^^^^^^^^^^^^^^^^^^^^%LF4%%LF4%^^^^^^^^%LF4%%LF4%"

:# Variables for use in inline macro functions
set ^"\n=%LF3%^^^"	&:# Insert a LF and continue macro on next line
set "^!=^^^^^^^!"	&:# Define a %!%DelayedExpansion%!% variable
set "'^!=^^^!"		&:# Idem, but inside a quoted string
set ">=^^^>"		&:# Insert a redirection character
set "<=^^^<"		&:# Insert a redirection character
set "&=^^^&"		&:# Insert a command separator in a macro
:# Idem, to be expanded twice, for use in macros within macros
set "^!2=^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^!"
set "'^!2=^^^^^^^!"
set "&2=^^^^^^^^^^^^^^^&"

set "MACRO=for %%$ in (1 2) do if %%$==2"				&:# Prolog code of a macro
set "/MACRO=else setlocal enableDelayedExpansion %&% set MACRO.ARGS="	&:# Epilog code of a macro
set "ENDMACRO=endlocal"	&:# Ends the macro local scope started in /MACRO. Necessary before macro exit.

set "ON_MACRO_EXIT=for /f "delims=" %%r in ('echo"	&:# Begin the return variables definitions 
set "/ON_MACRO_EXIT=') do %ENDMACRO% %&% %%r"		&:# End the return variables definitions

:# Primitive macro debugging definitions
:# Macros, usable anywhere, including within other macros, for conditionally displaying debug information
:# Use option -xd to set a > 0 macro debugging level.
:# Usage: %IF_XDLEVEL% N command
:# Runs command if the current macro debugging level is at least N.
:# Ex: %IF_XDLEVEL% 2 set VARIABLE
:# Recommended: Use set, instead of echo, to display variable values. This is sometimes
:# annoying because this displays other unwanted variables. But this is the only way
:# to be sure to display _all_ tricky characters correctly in any expansion mode. 
:# Note: These debugging macros slow down a lot their enclosing macro.
:#       They should be removed from the released code.
set "XDLEVEL=0" &:# 0=No macro debug; 1=medium debug; 2=full debug; 3=Even more debug
set "IF_XDLEVEL=for /f %%' in ('call echo.%%XDLEVEL%%') do if %%' GEQ"

goto :eof
:Macro.end

:#----------------------------------------------------------------------------#
:#                                                                            #
:#  Module	    Debug						      #
:#                                                                            #
:#  Description     A collection of debug routines                            #
:#                                                                            #
:#  Functions       Debug.Init	    Initialize debugging. Call once at first. #
:#                  Debug.Off	    Disable the debugging mode		      #
:#                  Debug.On	    Enable the debugging mode		      #
:#                  Debug.SetLog    Set the log file         		      #
:#                  Debug.Entry	    Log entry into a routine		      #
:#                  Debug.Return    Log exit from a routine		      #
:#                  Verbose.Off	    Disable the verbose mode                  #
:#                  Verbose.On	    Enable the verbose mode		      #
:#                  Echo	    Echo and log strings, indented            #
:#                  EchoVars	    Display the values of a set of variables  #
:#                  EchoArgs	    Display the values of all arguments       #
:#                                                                            #
:#  Macros          %FUNCTION%	    Define and trace the entry in a function. #
:#                  %UPVAR%         Declare a var. to pass back to the caller.#
:#                  %RETURN%        Return from a function and trace it       #
:#                                                                            #
:#                  Always match uses of %FUNCTION% and %RETURN%. That is     #
:#                  never use %RETURN% if there was no %FUNCTION% before it.  #
:#                                                                            #
:#                  :# Example of a factorial routine using this framework    #
:#                  :Fact                                                     #
:#                  %FUNCTION% enableextensions enabledelayedexpansion        #
:#		    %UPVAR% RETVAL					      #
:#                  set N=%1                                                  #
:#                  if .%N%.==.0. (                                           #
:#                    set RETVAL=1                                            #
:#                  ) else (                                                  #
:#                    set /A M=N-1                                            #
:#                    call :Fact !M!                                          #
:#                    set /A RETVAL=N*RETVAL                                  #
:#                  )                                                         #
:#                  %RETURN%					              #
:#                                                                            #
:#                  %ECHO%	    Echo and log a string, indented           #
:#                  %LOG%	    Log a string, indented                    #
:#                  %ECHO.V%	    Idem, but display it in verbose mode only #
:#                  %ECHO.D%	    Idem, but display it in debug mode only   #
:#                                                                            #
:#                  %ECHOVARS%	    Indent, echo and log variables values     #
:#                  %ECHOVARS.V%    Idem, but display them in verb. mode only #
:#                  %ECHOVARS.D%    Idem, but display them in debug mode only #
:#                                                                            #
:#                  %IF_DEBUG%      Execute a command in debug mode only      #
:#                  %IF_VERBOSE%    Execute a command in verbose mode only    #
:#                                                                            #
:#                  %FUNCTION0%	    Weak functions with no local variables.   #
:#                  %RETURN0%       Return from a %FUNCTION0% and trace it    #
:#                  %RETURN#%       Idem, with comments after the return      #
:#                                                                            #
:#  Variables       %>DEBUGOUT%     Debug output redirect. Either "" or ">&2".#
:#                  %LOGFILE%       Log file name. Inherited. Default=""==NUL #
:#                                  Always set using call :Debug.SetLog       #
:#                  %DEBUG%         Debug mode. 0=Off; 1=On. Use functions    #
:#                                  Debug.Off and Debug.On to change it.      #
:#                                  Inherited. Default=0.                     #
:#                  %VERBOSE%       Verbose mode. 0=Off; 1=On. Use functions  #
:#                                  Verbose.Off and Verbose.On to change it.  #
:#                                  Inherited. Default=0.                     #
:#                  %INDENT%        Spaces to put ahead of all debug output.  #
:#                                  Inherited. Default=. (empty string)       #
:#                                                                            #
:#  Notes           All output from these routines is sent to the log file.   #
:#                  In debug mode, the debug output is also sent to stderr.   #
:#                                                                            #
:#                  Traced functions are indented, based on the call depth.   #
:#                  Use %ECHO% to get the same indentation of normal output.  #
:#                                                                            #
:#                  The output format matches the batch language syntax       #
:#                  exactly. This allows copying the debug output directly    #
:#                  into another command window, to check troublesome code.   #
:#                                                                            #
:#  History                                                                   #
:#   2011-11-15 JFL Split Debug.Init from Debug.Off, to improve clarity.      #
:#   2011-12-12 JFL Output debug information to stderr, so that stdout can be #
:#                  used for returning information from the subroutine.       #
:#   2011-12-13 JFL Standardize use of RETVAR/RETVAL, and display it on return.
:#   2012-07-09 JFL Restructured functions to a more "object-like" style.     #
:#                  Added the three flavors of the Echo and EchoVars routines.#
:#   2012-07-19 JFL Added optimizations to improve performance in non-debug   #
:#                  and non-verbose mode. Added routine Debug.SetLog.         #
:#   2012-11-13 JFL Added macro LOG. Fixed setlocal bug in :EchoVars.         #
:#   2013-08-27 JFL Changed %RETURN% to do exit /b. This allows returning     #
:#                  an errorlevel by doing: %RETURN% %ERRORLEVEL%             #
:#   2013-11-12 JFL Added macros %IF_DEBUG% and %IF_VERBOSE%.                 #
:#   2013-12-04 JFL Added variable %>DEBUGOUT% to allow sending debug output  #
:#                  either to stdout or to stderr.                            #
:#   2015-10-29 JFL Added macro %RETURN#% to return with a comment.           #
:#   2015-11-19 JFL %FUNCTION% now automatically generates its name & %* args.#
:#                  (Simplifies usage, but comes at a cost of about a 5% slow #
:#                   down when running in debug mode.)                        #
:#                  Added an %UPVAR% macro allowing to define the list of     #
:#                  variables that need to make it back to the caller.        #
:#                  %RETURN% (Actually the Debug.return routine) now handles  #
:#                  this variable back propagation using the (goto) trick.    #
:#                  This works well, but the performance is poor.             #
:#   2015-11-25 JFL Rewrote the %FUNCTION% and %RETURN% macros to manage      #
:#                  most common cases without calling a subroutine. This      #
:#                  resolves the performance issues of the previous version.  #
:#   2015-11-27 JFL Redesigned the problematic character return mechanism     #
:#                  using a table of predefined generic entities. Includes    #
:#                  support for returning strings with CR & LF.		      #
:#   2015-11-29 JFL Streamlined the macros and added lots of comments.        #
:#                  The FUNCTION macro now runs with expansion enabled, then  #
:#                  does a second setlocal in the end as requested.           #
:#                  The RETURN macro now displays strings in debug mode with  #
:#                  delayed expansion enabled. This fixes issues with CR & LF.#
:#                  Added a backspace entity.                                 #
:#   2015-12-01 JFL Bug fix: %FUNCTION% with no arg did change the exp. mode. #
:#   2016-09-01 JFL Bug fix: %RETURN% incorrectly returned empty variables.   #
:#   2016-11-02 JFL Bug fix: Avoid log file redirection failures in recursive #
:#                  scripts.                                                  #
:#   2016-11-13 JFL Bug fix: Correctly return special characters & | < > ? *  #
:#   2016-11-24 JFL Fixed tracing %FUNCTION% arguments with ^ and % chars.    #
:#                                                                            #
:#----------------------------------------------------------------------------#

call :Debug.Init
goto :Debug.End

:Debug.Init
:# Preliminary checks to catch common problems
if exist echo >&2 echo WARNING: The file "echo" in the current directory will cause problems. Please delete it and retry.
:# Inherited variables from the caller: DEBUG, VERBOSE, INDENT, >DEBUGOUT
:# Initialize other debug variables
set "ECHO=%LCALL% :Echo"
set "ECHOVARS=%LCALL% :EchoVars"
:# The FUNCTION, UPVAR, and RETURN macros should work with delayed expansion on or off
set MACRO.GETEXP=(if "%'!2%%'!2%"=="" (set MACRO.EXP=EnableDelayedExpansion) else set MACRO.EXP=DisableDelayedExpansion)
set UPVAR=call set DEBUG.RETVARS=%%DEBUG.RETVARS%%
set RETURN=call set "DEBUG.ERRORLEVEL=%%ERRORLEVEL%%" %&% %MACRO% ( %\n%
  set DEBUG.EXITCODE=%!%MACRO.ARGS%!%%\n%
  if defined DEBUG.EXITCODE set DEBUG.EXITCODE=%!%DEBUG.EXITCODE: =%!%%\n%
  if not defined DEBUG.EXITCODE set DEBUG.EXITCODE=%!%DEBUG.ERRORLEVEL%!%%\n%
  for %%l in ("%'!%LF%'!%") do ( %# Make it easy to insert line-feeds in any mode #% %\n%
    set "DEBUG.SETARGS=""" %# The initial "" makes sure that for loops below never get an empty arg list #% %\n%
    for %%v in (%!%DEBUG.RETVARS%!%) do ( %\n%
      set "DEBUG.VALUE=%'!%%%v%'!%" %# We must remove problematic characters in that value #% %\n%
      if defined DEBUG.VALUE ( %# Else the following lines will generate phantom characters #% %\n%
	set "DEBUG.VALUE=%'!%DEBUG.VALUE:%%=%%DEBUG.percnt%%%'!%"	%# Encode percent #% %\n%
	for %%e in (sp tab cr lf quot amp vert lt gt) do for %%c in ("%'!%DEBUG.%%e%'!%") do ( %# Encode named character entities #% %\n%
	  set "DEBUG.VALUE=%'!%DEBUG.VALUE:%%~c=%%DEBUG.%%e%%%'!%" %\n%
	) %\n%
	set "DEBUG.VALUE=%'!%DEBUG.VALUE:^^=%%DEBUG.hat%%%'!%"	%# Encode carets #% %\n%
	call set "DEBUG.VALUE=%%DEBUG.VALUE:%!%=^^^^%%" 		%# Encode exclamation points #% %\n%
	set "DEBUG.VALUE=%'!%DEBUG.VALUE:^^^^=%%DEBUG.excl%%%'!%"	%# Encode exclamation points #% %\n%
      ) %\n%
      set DEBUG.SETARGS=%!%DEBUG.SETARGS%!% "%%v=%'!%DEBUG.VALUE%'!%"%\n%
    ) %\n%
    if %!%DEBUG%!%==1 ( %# Build the debug message and display it #% %\n%
      set "DEBUG.MSG=return %'!%DEBUG.EXITCODE%'!%" %\n%
      for /f "delims=" %%v in ("%'!%DEBUG.SETARGS: =%%~l%'!%") do if not %%v=="" ( %# for /f avoids issues with ? and * #% %\n%
	set "DEBUG.MSG=%'!%DEBUG.MSG%'!% %%DEBUG.amp%% set %%v" %!% %\n%
      ) %\n%
      call set "DEBUG.MSG=%'!%DEBUG.MSG:%%=%%DEBUG.excl%%%'!%" %# Change all percent to ! #%  %\n%
      if defined ^^%>%DEBUGOUT ( %# If we use a debugging stream distinct from stdout #% %\n%
	%LCALL% :Echo.Eval2DebugOut DEBUG.MSG %# Use a helper routine, as delayed redirection does not work #% %\n%
      ) else ( %# Output directly here, which is faster #% %\n%
	for /f "delims=" %%c in ("%'!%INDENT%'!%%'!%DEBUG.MSG%'!%") do echo %%c%# Use a for loop to do a double !variable! expansion #%%\n%
      ) %\n%
      if defined LOGFILE ( %# If we have to send a copy to a log file #% %\n%
	%LCALL% :Echo.Eval2LogFile DEBUG.MSG %# Use a helper routine, as delayed redirection does not work #% %\n%
      ) %\n%
    ) %\n%
    for %%r in (%!%DEBUG.EXITCODE%!%) do ( %# Carry the return values through the endlocal barriers #% %\n%
      for /f "delims=" %%a in ("%'!%DEBUG.SETARGS%'!%") do ( %\n%
	endlocal %&% endlocal %&% endlocal %# Exit the RETURN and FUNCTION local scopes #% %\n%
	set "DEBUG.SETARGS=%%a" %\n%
	if "%'!%%'!%"=="" ( %# Delayed expansion is ON #% %\n%
	  call set "DEBUG.SETARGS=%'!%DEBUG.SETARGS:%%=%%DEBUG.excl%%%'!%" %# Change all percent to ! #%  %\n%
	  for /f "delims=" %%v in ("%'!%DEBUG.SETARGS: =%%~l%'!%") do if not %%v=="" ( %# for /f avoids issues with ? and * #% %\n%
	    set %%v %# Set each upvar variable in the caller's scope #% %\n%
	  ) %\n%
	) else ( %# Delayed expansion is OFF #% %\n%
	  setlocal EnableDelayedExpansion %\n%
	  for /f "delims=" %%v in ("%'!%DEBUG.SETARGS: =%%~l%'!%") do if %%v=="" ( %# for /f avoids issues with ? and * #% %\n%
	    endlocal %\n%
	  ) else ( %\n%
	    call set %%v %# Set each upvar variable in the caller's scope #% %\n%
	  ) %\n%
	) %\n%
	set "DEBUG.SETARGS=" %\n%
	exit /b %%r %# Return to the caller #% %\n%
      ) %\n%
    ) %\n%
  ) %\n%
) %/MACRO%
:Debug.Init.2
set "LOG=%LCALL% :Echo.Log"
set ">>LOGFILE=>>%LOGFILE%"
if not defined LOGFILE set "LOG=rem" & set ">>LOGFILE=rem"
if .%LOGFILE%.==.NUL. set "LOG=rem" & set ">>LOGFILE=rem"
if .%NOREDIR%.==.1. set "LOG=rem" & set ">>LOGFILE=rem" &:# A parent script is already redirecting output. Trying to do it again here would fail. 
set "ECHO.V=%LCALL% :Echo.Verbose"
set "ECHO.D=%LCALL% :Echo.Debug"
set "ECHOVARS.V=%LCALL% :EchoVars.Verbose"
set "ECHOVARS.D=%LCALL% :EchoVars.Debug"
:# Variables inherited from the caller...
:# Preserve INDENT if it contains just spaces, else clear it.
for /f %%s in ('echo.%INDENT%') do set "INDENT="
:# Preserve the log file name, else by default use NUL.
:# if not defined LOGFILE set "LOGFILE=NUL"
:# VERBOSE mode can only be 0 or 1. Default is 0.
if not .%VERBOSE%.==.1. set "VERBOSE=0"
call :Verbose.%VERBOSE%
:# DEBUG mode can only be 0 or 1. Default is 0.
if not .%DEBUG%.==.1. set "DEBUG=0"
goto :Debug.%DEBUG%

:Debug.SetLog
set "LOGFILE=%~1"
goto :Debug.Init.2

:Debug.Off
:Debug.0
set "DEBUG=0"
set "DEBUG.ENTRY=rem"
set "IF_DEBUG=if .%DEBUG%.==.1."
set "FUNCTION0=rem"
set FUNCTION=%MACRO.GETEXP% %&% %MACRO% ( %\n%
  call set "FUNCTION.NAME=%%0" %\n%
  call set ARGS=%%*%# Do not quote this, to keep string/non string aternance #%%\n%
  if defined ARGS set ARGS=%!%ARGS:^^^^^^^^^^^^^^^^=^^^^^^^^%!%%# ^carets are doubled in quoted strings, halved outside. => Quadruple them if using unquoted ones #%%\n%
  set "DEBUG.RETVARS=" %\n%
  if not defined MACRO.ARGS set "MACRO.ARGS=%'!%MACRO.EXP%'!%" %\n%
  setlocal %!%MACRO.ARGS%!% %\n%
) %/MACRO%
set "RETURN0=exit /b"
set "RETURN#=exit /b & rem"
set "EXEC.ARGS= %EXEC.ARGS%"
set "EXEC.ARGS=%EXEC.ARGS: -d=%"
set "EXEC.ARGS=%EXEC.ARGS:~1%"
:# Optimization to speed things up in non-debug mode
if not defined LOGFILE set "ECHO.D=rem"
if .%LOGFILE%.==.NUL. set "ECHO.D=rem"
if not defined LOGFILE set "ECHOVARS.D=rem"
if .%LOGFILE%.==.NUL. set "ECHOVARS.D=rem"
goto :eof

:Debug.On
:Debug.1
set "DEBUG=1"
set "DEBUG.ENTRY=:Debug.Entry"
set "IF_DEBUG=if .%DEBUG%.==.1."
set "FUNCTION0=call %LCALL% :Debug.Entry0 %%0 %%*"
set FUNCTION=%MACRO.GETEXP% %&% %MACRO% ( %\n%
  call set "FUNCTION.NAME=%%0" %\n%
  call set ARGS=%%*%# Do not quote this, to keep string/non string aternance #%%\n%
  if defined ARGS set ARGS=%!%ARGS:^^^^^^^^^^^^^^^^=^^^^^^^^%!%%# ^carets are doubled in quoted strings, halved outside. => Quadruple them if using unquoted ones #%%\n%
  if %!%DEBUG%!%==1 ( %# Build the debug message and display it #% %\n%
    set DEBUG.MSG=call %!%FUNCTION.NAME%!% %!%ARGS%!%%\n%
    if defined ^^%>%DEBUGOUT ( %# If we use a debugging stream distinct from stdout #% %\n%
      %LCALL% :Echo.2DebugOut DEBUG.MSG %# Use a helper routine, as delayed redirection does not work #% %\n%
    ) else ( %# Output directly here, which is faster #% %\n%
      echo%!%INDENT%!% %!%DEBUG.MSG%!%%\n%
    ) %\n%
    if defined LOGFILE ( %# If we have to send a copy to a log file #% %\n%
      %LCALL% :Echo.2LogFile DEBUG.MSG %# Use a helper routine, as delayed redirection does not work #% %\n%
    ) %\n%
    call set "INDENT=%'!%INDENT%'!%  " %\n%
  ) %\n%
  set "DEBUG.RETVARS=" %\n%
  if not defined MACRO.ARGS set "MACRO.ARGS=%'!%MACRO.EXP%'!%" %\n%
  setlocal %!%MACRO.ARGS%!% %\n%
) %/MACRO%
set "RETURN0=call %LCALL% :Debug.Return0 %%ERRORLEVEL%% & exit /b"
:# Macro for displaying comments on the return log line
set RETURN#=call set "RETURN.ERR=%%ERRORLEVEL%%" %&% %MACRO% ( %\n%
  %LCALL% :Debug.Return# %# Redirections can't work in macro. Do it in a function. #% %\n%
  for %%r in (%!%RETURN.ERR%!%) do %ENDMACRO% %&% set "RETURN.ERR=" %&% call set "INDENT=%%INDENT:~2%%" %&% exit /b %%r %\n%
) %/MACRO%
set "EXEC.ARGS= %EXEC.ARGS%"
set "EXEC.ARGS=%EXEC.ARGS: -d=% -d"
set "EXEC.ARGS=%EXEC.ARGS:~1%"
:# Reverse the above optimization
set "ECHO.D=%LCALL% :Echo.Debug"
set "ECHOVARS.D=%LCALL% :EchoVars.Debug"
goto :eof

:Debug.Entry0
setlocal DisableDelayedExpansion
%>DEBUGOUT% echo %INDENT%call %*
if defined LOGFILE %>>LOGFILE% echo %INDENT%call %*
endlocal
set "INDENT=%INDENT%  "
goto :eof

:Debug.Entry
setlocal DisableDelayedExpansion
%>DEBUGOUT% echo %INDENT%call %FUNCTION.NAME% %ARGS%
if defined LOGFILE %>>LOGFILE% echo %INDENT%call %FUNCTION.NAME% %ARGS%
endlocal
set "INDENT=%INDENT%  "
goto :eof

:Debug.Return0 %1=Exit code
%>DEBUGOUT% echo %INDENT%return %1
if defined LOGFILE %>>LOGFILE% echo %INDENT%return %1
set "INDENT=%INDENT:~0,-2%"
exit /b %1

:Debug.Return# :# %RETURN.ERR% %MACRO.ARGS%
setlocal DisableDelayedExpansion
%>DEBUGOUT% echo %INDENT%return %RETURN.ERR% ^&:#%MACRO.ARGS%
if defined LOGFILE %>>LOGFILE% echo %INDENT%return %RETURN.ERR% ^&:#%MACRO.ARGS%
endlocal
goto :eof &:# %RETURN.ERR% will be processed in the %DEBUG#% macro.

:# Routine to set the VERBOSE mode, in response to the -v argument.
:Verbose.Off
:Verbose.0
set "VERBOSE=0"
set "IF_VERBOSE=if .%VERBOSE%.==.1."
set "EXEC.ARGS= %EXEC.ARGS%"
set "EXEC.ARGS=%EXEC.ARGS: -v=%"
set "EXEC.ARGS=%EXEC.ARGS:~1%"
:# Optimization to speed things up in non-verbose mode
if not defined LOGFILE set "ECHO.V=rem"
if .%LOGFILE%.==.NUL. set "ECHO.V=rem"
if not defined LOGFILE set "ECHOVARS.V=rem"
if .%LOGFILE%.==.NUL. set "ECHOVARS.V=rem"
goto :eof

:Verbose.On
:Verbose.1
set "VERBOSE=1"
set "IF_VERBOSE=if .%VERBOSE%.==.1."
set "EXEC.ARGS= %EXEC.ARGS%"
set "EXEC.ARGS=%EXEC.ARGS: -v=% -v"
set "EXEC.ARGS=%EXEC.ARGS:~1%"
:# Reverse the above optimization
set "ECHO.V=%LCALL% :Echo.Verbose"
set "ECHOVARS.V=%LCALL% :EchoVars.Verbose"
goto :eof

:# Echo and log a string, indented at the same level as the debug output.
:Echo
echo.%INDENT%%*
:Echo.Log
if defined LOGFILE %>>LOGFILE% echo.%INDENT%%*
goto :eof

:Echo.Verbose
:Echo.V
%IF_VERBOSE% goto :Echo
goto :Echo.Log

:Echo.Debug
:Echo.D
%IF_DEBUG% %>DEBUGOUT% echo.%INDENT%%*
goto :Echo.Log

:Echo.Eval2DebugOut %1=Name of string, with !variables! that need to be evaluated first
setlocal EnableDelayedExpansion &:# Make sure that !variables! get expanded
set "STRING=!%1!" &:# !variables! not yet expanded; They will be on next line
%>DEBUGOUT% echo.%INDENT%%STRING%
goto :eof

:Echo.2DebugOut	%1=Name of string to output to the DEBUGOUT stream
setlocal EnableDelayedExpansion &:# Make sure that !variables! get expanded
%>DEBUGOUT% echo.%INDENT%!%1!
goto :eof

:Echo.Eval2LogFile %1=Name of string, with variables that need to be evaluated first
setlocal EnableDelayedExpansion &:# Make sure that !variables! get expanded
set "STRING=!%1!" &:# !variables! not yet expanded; They will be on next line
%>>LOGFILE% echo.%INDENT%%STRING%
goto :eof

:Echo.2LogFile %1=Name of string to output to the LOGFILE
setlocal EnableDelayedExpansion &:# Make sure that !variables! get expanded
%>>LOGFILE% echo.%INDENT%!%1!
goto :eof

:# Echo and log variable values, indented at the same level as the debug output.
:EchoVars
setlocal EnableExtensions EnableDelayedExpansion
:EchoVars.loop
if "%~1"=="" endlocal & goto :eof
%>DEBUGOUT% echo %INDENT%set "%~1=!%~1!"
if defined LOGFILE %>>LOGFILE% echo %INDENT%set "%~1=!%~1!"
shift
goto EchoVars.loop

:EchoVars.Verbose
%IF_VERBOSE% (
  call :EchoVars %*
) else ( :# Make sure the variables are logged
  call :EchoVars %* >NUL 2>NUL
)
goto :eof

:EchoVars.Debug
%IF_DEBUG% (
  call :EchoVars %*
) else ( :# Make sure the variables are logged
  call :EchoVars %* >NUL 2>NUL
)
goto :eof

:# Echo a list of arguments.
:EchoArgs
setlocal EnableExtensions DisableDelayedExpansion
set N=0
:EchoArgs.loop
if .%1.==.. endlocal & goto :eof
set /a N=N+1
%>DEBUGOUT% echo %INDENT%set "ARG%N%=%1"
shift
goto EchoArgs.loop

:Debug.End

:#----------------------------------------------------------------------------#
:#                                                                            #
:#  Module	    Exec                                                      #
:#                                                                            #
:#  Description     Run a command, logging its output to the log file.        #
:#                                                                            #
:#                  In VERBOSE mode, display the command line first.          #
:#                  In DEBUG mode, display the command line and the exit code.#
:#                  In NOEXEC mode, display the command line, but don't run it.
:#                                                                            #
:#  Functions       Exec.Init	Initialize Exec routines. Call once at 1st    #
:#                  Exec.Off	Disable execution of commands		      #
:#                  Exec.On	Enable execution of commands		      #
:#                  Do          Always execute a command, logging its output  #
:#                  Exec	Conditionally execute a command, logging it.  #
:#                  Exec.SetErrorLevel	Change the current ERRORLEVEL	      #
:#                                                                            #
:#  Exec Arguments  -l          Log the output to the log file.               #
:#                  -L          Do not send the output to the log file. (Dflt)#
:#                  -t          Tee all output to the log file if there's a   #
:#                              usable tee.exe.                               #
:#                              Known limitation: The exit code is always 0.  #
:#                  -e          Always echo the command.		      #
:#		    -f		Force executing the command, even in NOEXEC m.#
:#                  -v          Trace the command in verbose mode. (Default)  #
:#                  -V          Do not trace the command in verbose mode.     #
:#                  %*          The command and its arguments                 #
:#                              Quote redirection operators. Ex:              #
:#                              %EXEC% find /I "error" "<"logfile.txt ">"NUL  #
:#                              Note: Quote redirections, NOT file numbers.   #
:#                              Ex: 2">&"1 will work; "2>&1" will NOT work.   #
:#                                                                            #
:#  Macros          %DO%        Always execute a command, logging its output  #
:#                  %EXEC%      Conditionally execute a command, logging it.  #
:#                  %ECHO.X%    Echo a string indented in -X mode, and log it.#
:#                  %ECHO.XD%   Idem in -X or -D modes.                       #
:#                  %ECHO.XVD%  Idem in -X or -V or -D modes.                 #
:#                              Useful to display commands in cases where     #
:#                              %EXEC% can't be used, like in for ('cmd') ... #
:#                  %IF_EXEC%   Execute a command if _not_ in NOEXEC mode     #
:#                  %IF_NOEXEC% Execute a command in NOEXEC mode only         #
:#                  %_DO%       Echo and run a command. No opts. No logging.  #
:#                  %_DO.D%     Idem, echoing it in debug mode only.          #
:#                  %_DO.XVD%   Idem, echoing it in -X or -V or -D modes only.#
:#                  %XEXEC%     Call :Exec from an external scriptlet, such   #
:#                               one in a (for /f in ('commands')) block.     #
:#                  %XEXEC@%    Idem, but with all args stored in one var.    #
:#                                                                            #
:#  Variables       %NOEXEC%	Exec mode. 0=Execute commands; 1=Don't. Use   #
:#                              functions Exec.Off and Exec.On to change it.  #
:#                              Inherited from the caller. Default=On.	      #
:#                  %NOREDIR%   0=Log command output to the log file; 1=Don't #
:#                              Inherited. Default=0.                         #
:#                              Useful in cases where the output must be      #
:#                              shown to the user, and no tee.exe is available.
:#                  %EXEC.ARGS%	Arguments to recursively pass to subcommands  #
:#                              with the same execution options conventions.  #
:#                                                                            #
:#  Notes           %EXEC% can't be used from inside ('command') blocks.      #
:#                  This is because these blocks are executed separately in   #
:#                  a child shell. Use %XEXEC% or %XEXEC@% instead.	      #
:#		    These macros rely on the %XCALL% mechanism for calling    #
:#		    subroutines in a second instance of a script. They depend #
:#		    on the following line being present after the ARGS	      #
:#		    variable definition at the top of your script:	      #
:#		    if '%1'=='-call' !ARGS:~1!& exit /b			      #
:#                                                                            #
:#  History                                                                   #
:#   2010-05-19 JFL Created this routine.                                     #
:#   2012-05-04 JFL Support logging ">" redirections.                         #
:#   2012-07-09 JFL Restructured functions to a more "object-like" style.     #
:#   2012-07-11 JFL Support logging both "<" and ">" redirections.            #
:#   2012-09-18 JFL Added macro %ECHO.X% for cases where %EXEC% can't be used.#
:#   2012-11-13 JFL Support for "|" pipes too.                                #
:#   2013-11-12 JFL Added macro %IF_NOEXEC%.                                  #
:#   2013-12-04 JFL Added option -t to tee the output if possible.            #
:#                  Split %ECHO.X% and %ECHO.XVD%.                            #
:#   2014-05-13 JFL Call tee.exe explicitely, to avoid problems if there's    #
:#                  also a tee.bat script in the path.                        #
:#   2015-03-12 JFL If there are output redirections, then cancel any attempt #
:#		    at redirecting output to the log file.		      #
:#   2016-10-19 JFL Bug fix: Make sure the :Exec initialization preserves the #
:#                  errorlevel that was there on entrance.                    #
:#   2016-11-02 JFL Bug fix: Avoid log file redirection failures in recursive #
:#                  scripts.                                                  #
:#   2016-11-05 JFL Fixed :Exec bug in XP/64.				      #
:#                  Indent sub-scripts output in debug mode.                  #
:#   2016-11-06 JFL Updated the 10/19 errorlevel fix to work for DO and EXEC. #
:#   2016-11-17 JFL Fixed tracing the exit code when caller has exp. disabled.#
:#		    Added option -V to disable tracing exec in verbose mode.  #
:#		    Added macro %ECHO.XD%.                                    #
:#		    Faster and more exact method for separating the %EXEC%    #
:#		    optional arguments from the command line to run. (The old #
:#		    method lost non-white batch argument separators = , ; in  #
:#		    some cases.)                                              #
:#   2016-11-24 JFL Fixed executing commands containing a ^ character.        #
:#		    Added routine :_Do.                                       #
:#   2016-12-13 JFL Rewrote _DO as a pure macro.                              #
:#   2016-12-15 JFL Changed the default to NOT redirecting the output to log. #
:#   2017-01-13 JFL Added option -f to routine :Exec.                         #
:#		                                                              #
:#----------------------------------------------------------------------------#

call :Exec.Init
goto :Exec.End

:# Global variables initialization, to be called first in the main routine
:Exec.Init
set "DO=%LCALL% :Do"
set "EXEC=%LCALL% :Exec"
set "ECHO.X=%LCALL% :Echo.X"
set "ECHO.XD=%LCALL% :Echo.XD"
set "ECHO.XVD=%LCALL% :Echo.XVD"
if not .%NOEXEC%.==.1. set "NOEXEC=0"
:# Quick and simple DO macros, supporting a single command, no redirections, no tricky chars!
set _DO=%MACRO%     ( %LCALL% :Echo     %!%MACRO.ARGS%!% %&% %ON_MACRO_EXIT%%!%MACRO.ARGS%!%%/ON_MACRO_EXIT% ) %/MACRO%
set _DO.D=%MACRO%   ( %LCALL% :Echo.D   %!%MACRO.ARGS%!% %&% %ON_MACRO_EXIT%%!%MACRO.ARGS%!%%/ON_MACRO_EXIT% ) %/MACRO%
set _DO.XD=%MACRO%  ( %LCALL% :Echo.XD  %!%MACRO.ARGS%!% %&% %ON_MACRO_EXIT%%!%MACRO.ARGS%!%%/ON_MACRO_EXIT% ) %/MACRO%
set _DO.XVD=%MACRO% ( %LCALL% :Echo.XVD %!%MACRO.ARGS%!% %&% %ON_MACRO_EXIT%%!%MACRO.ARGS%!%%/ON_MACRO_EXIT% ) %/MACRO%
:# Execute commands from another instance of the main script
set "XEXEC=%XCALL% :Exec"
set "XEXEC@=%XCALL% :Exec.ExecVar"
:# Check if there's a tee.exe program available
:# set "Exec.HaveTee=0"
:# tee.exe --help >NUL 2>NUL
:# if not errorlevel 1 set "Exec.HaveTee=1"
for %%t in (tee.exe) do set "Exec.tee=%%~$PATH:t"
:# Initialize ERRORLEVEL with known values
set "TRUE.EXE=(call,)"	&:# Macro to silently set ERRORLEVEL to 0
set "FALSE.EXE=(call)"	&:# Macro to silently set ERRORLEVEL to 1
goto :NoExec.%NOEXEC%

:Exec.On
:NoExec.0
set "NOEXEC=0"
set "IF_NOEXEC=if .%NOEXEC%.==.1."
set "IF_EXEC=if .%NOEXEC%.==.0."
set "EXEC.ARGS= %EXEC.ARGS%"
set "EXEC.ARGS=%EXEC.ARGS: -X=%"
set "EXEC.ARGS=%EXEC.ARGS:~1%"
goto :eof

:# Routine to set the NOEXEC mode, in response to the -X argument.
:Exec.Off
:NoExec.1
set "NOEXEC=1"
set "IF_NOEXEC=if .%NOEXEC%.==.1."
set "IF_EXEC=if .%NOEXEC%.==.0."
set "EXEC.ARGS= %EXEC.ARGS%"
set "EXEC.ARGS=%EXEC.ARGS: -X=% -X"
set "EXEC.ARGS=%EXEC.ARGS:~1%"
goto :eof

:Echo.XVD
%IF_VERBOSE% goto :Echo
:Echo.XD
%IF_DEBUG% goto :Echo
:Echo.X
%IF_NOEXEC% goto :Echo
goto :Echo.Log

:Exec.SetErrorLevel %1
exit /b %1

:# Execute a command, logging its output.
:# Use for informative commands that should always be run, even in NOEXEC mode. 
:Do
set "Exec.ErrorLevel=%ERRORLEVEL%" &:# Save the initial errorlevel
setlocal EnableExtensions DisableDelayedExpansion &:# Clears the errorlevel
%IF_NOEXEC% call :Exec.On
goto :Exec.Start

:# Execute critical operations that should not be run in NOEXEC mode.
:# Version supporting input and output redirections, and pipes.
:# Redirection operators MUST be surrounded by quotes. Ex: "<" or ">" or ">>"
:Exec
set "Exec.ErrorLevel=%ERRORLEVEL%" &:# Save the initial errorlevel
setlocal EnableExtensions DisableDelayedExpansion &:# Clears the errorlevel
:Exec.Start
set "Exec.NOREDIR=%NOREDIR%"
set "Exec.Redir="				&:# The selected redirection. Default: none
set "Exec.2Redir=>>%LOGFILE%,2>&1"		&:# What to change it to, to enable redirection
if .%NOREDIR%.==.1. set "Exec.2Redir="		&:# Several cases forbid redirection
if not defined LOGFILE set "Exec.2Redir="
if /i .%LOGFILE%.==.NUL. set "Exec.2Redir="
set "Exec.IF_VERBOSE=%IF_VERBOSE%"		&:# Echo the command in verbose mode
set "Exec.IF_EXEC=%IF_EXEC%"			&:# IF_EXEC macro
set "Exec.IF_NOEXEC=%IF_NOEXEC%"		&:# IF_NOEXEC macro
:# Record the command-line to execute.
:# Never comment (set Exec.cmd) lines themselves, to avoid appending extra spaces.
:# Use %*, but not %1 ... %9, because %N miss non-white argument separators like = , ;
set ^"Exec.Cmd=%*^" &:# Doubles ^carets within "quoted" strings, and halves those outside
set ^"Exec.Cmd=%Exec.Cmd:^^=^%^" &:# Fix the # of ^carets within "quoted" strings
:# Process optional arguments
goto :Exec.GetArgs
:Exec.NextArg
:# Remove the %EXEC% argument and following spaces from the head of the command line
setlocal EnableDelayedExpansion &:# The next line works because no :exec own argument may contain an '=' or a '!'
for /f "tokens=1* delims= " %%a in ("-!Exec.Cmd:*%1=!") do endlocal & set Exec.Cmd=%%b
shift
:Exec.GetArgs
if "%~1"=="-l" set "Exec.Redir=%Exec.2Redir%" & goto :Exec.NextArg :# Do send the output to the log file
if "%~1"=="-L" set "Exec.Redir=" & goto :Exec.NextArg :# Do not send the output to the log file
if "%~1"=="-t" if defined Exec.2Redir ( :# Tee the output to the log file
  :# Warning: This prevents from getting the command exit code!
  if defined Exec.tee set "Exec.Redir= 2>&1 | %Exec.tee% -a %LOGFILE%"
  goto :Exec.NextArg
)
if "%~1"=="-e" set "Exec.IF_VERBOSE=if 1==1" & goto :Exec.NextArg :# Always echo the command
if "%~1"=="-f" set "Exec.IF_EXEC=if 1==1" & set "Exec.IF_NOEXEC=if 0==1" & goto :Exec.NextArg :# Always execute the command
if "%~1"=="-v" set "Exec.IF_VERBOSE=%IF_VERBOSE%" & goto :Exec.NextArg :# Echo the command in verbose mode
if "%~1"=="-V" set "Exec.IF_VERBOSE=if 0==1" & goto :Exec.NextArg :# Do not echo the command in verbose mode
:# Anything else is part of the command. Prepare to display it and run it.
:# First stage: Split multi-char ops ">>" "2>" "2>>". Make sure to keep ">" signs quoted every time.
:# Do NOT use surrounding quotes for these set commands, else quoted arguments will break.
set Exec.Cmd=%Exec.Cmd:">>"=">"">"%
set Exec.Cmd=%Exec.Cmd:">>&"=">"">""&"%
set Exec.Cmd=%Exec.Cmd:">&"=">""&"%
:# If there are output redirections, then cancel any attempt at redirecting output to the log file.
set "Exec.Cmd1=%Exec.Cmd:"=%" &:# Remove quotes in the command string, to allow quoting the whole string.
if not "%Exec.Cmd1:>=%"=="%Exec.Cmd1%" set "Exec.Redir="
if defined Exec.Redir set "Exec.NOREDIR=1" &:# make sure child scripts do not try to redirect output again 
:# Second stage: Convert quoted redirection operators (Ex: ">") to a usable (Ex: >) and a displayable (Ex: ^>) value.
:# Must be done once for each of the four < > | & operators.
:# Since each operation removes half of ^ escape characters, then insert
:# enough ^ to still protect the previous characters during the subsequent operations.
set Exec.toEcho=%Exec.Cmd:"|"=^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^|%
set Exec.toEcho=%Exec.toEcho:"&"=^^^^^^^^^^^^^^^&%
set Exec.toEcho=%Exec.toEcho:">"=^^^^^^^>%
set Exec.toEcho=%Exec.toEcho:"<"=^^^<%
:# Finally create the usable command, by removing the last level of ^ escapes.
set Exec.Cmd=%Exec.toEcho%
set "Exec.Echo=rem"
%Exec.IF_NOEXEC% set "Exec.Echo=echo"
%IF_DEBUG% set "Exec.Echo=echo"
%Exec.IF_VERBOSE% set "Exec.Echo=echo"
%>DEBUGOUT% %Exec.Echo%.%INDENT%%Exec.toEcho%
if defined LOGFILE %>>LOGFILE% echo.%INDENT%%Exec.toEcho%
:# Constraints at this stage:
:# The command exit code must make it through, back to the caller.
:# The local variables must disappear before return.
:# But the new variables created by the command must make it through.
:# This should work whether :Exec is called with delayed expansion on or off.
endlocal & %Exec.IF_EXEC% (
  set "NOREDIR=%Exec.NOREDIR%"
  %IF_DEBUG% set "INDENT=%INDENT%  "
  call :Exec.SetErrorLevel %Exec.ErrorLevel% &:# Restore the errorlevel we had on :Exec entrance
  %Exec.Cmd%%Exec.Redir%
  call set "Exec.ErrorLevel=%%ERRORLEVEL%%"  &:# Save the new errorlevel set by the command executed
  set "NOREDIR=%NOREDIR%" &:# Sets ERRORLEVEL=1 in Windows XP/64
  %IF_DEBUG% set "INDENT=%INDENT%"
  call :Exec.TraceExit
)
exit /b

:Exec.TraceExit
for %%e in (%Exec.ErrorLevel%) do (
  set "Exec.ErrorLevel="
  %IF_DEBUG% %>DEBUGOUT% echo.%INDENT%  exit %%e
  if defined LOGFILE %>>LOGFILE% echo.%INDENT%  exit %%e
  exit /b %%e
)

:Exec.ExecVar CMDVAR
call :Exec !%1:%%=%%%%!
exit /b

:Exec.End

:#----------------------------------------------------------------------------#
:#                        End of the debugging library                        #
:#----------------------------------------------------------------------------#

:#----------------------------------------------------------------------------#
:#                                                                            #
:#  Function        Echo.Color						      #
:#                                                                            #
:#  Description     Echo colored strings                                      #
:#                                                                            #
:#  Arguments                                                                 #
:#                                                                            #
:#  Notes 	    Based on the colorPrint sample code in                    #
:#                  http://stackoverflow.com/questions/4339649/how-to-have-multiple-colors-in-a-batch-file
:#                                                                            #
:#                  Requires ending the script with a last line containing    #
:#                  a single dash "-" and no CRLF in the end.                 #
:#                                                                            #
:#                  Known limitations:                                        #
:#                  Backspaces do not work across a line break, so the        #
:#                  technique can have problems if the line wraps.            #
:#                  For example, printing a string with length between 74-79  #
:#                  will not work properly in a 80-columns console.           #
:#                                                                            #
:#  History                                                                   #
:#   2011-03-17 JEB Published the first sample on stackoverflow.com           #
:#   2012-04-30 JEB Added support for strings containing invalid file name    #
:#                  characters, by using the \..\x suffix.                    #
:#   2012-05-02 DB  Added support for strings that contain additional path    #
:#                  levels, like: "a\b\" "a/b/" "\" "/" "." ".." "c:"         #
:#                  Store the temp file on %TEMP%, which is always writable.  #
:#                  Created 2 variants, one takes a string literal, the other #
:#                  the name of a variable containing the string. The variable#
:#                  version is generally less convenient, but it eliminates   #
:#                  some special character escape issues.                     #
:#                  Added the /n option as an optional 3rd parameter to       #
:#                  append a newline at the end of the output.                #
:#   2012-09-26 JFL Renamed routines as object-oriented Echo.Methods.         #
:#                  Added routines Echo.Success, Echo.Warning, Echo.Failure.  #
:#   2012-10-02 JFL Renamed variable DEL as ECHO.DEL to avoid name collisions.#
:#                  Removed the . in the temp file. findstr can search a BS.  #
:#                  Removed a call level to improve performance a bit.        #
:#                  Added comments.                                           #
:#                  New implementation not using a temporary file.            #
:#   2012-10-06 JFL Fixed the problem with displaying "!".                    #
:#   2012-11-13 JFL Copy the string into the log file, if defined.            #
:#   2017-01-16 JFL Use bright colors for [Success]/[Warning]/[Failure],      #
:#                  and added an optional suffix and end of line.             #
:#   2017-01-25 JFL Changed the final string to valid PowerShell comment ##-  #
:#                                                                            #
:#----------------------------------------------------------------------------#

call :Echo.Color.Init
goto Echo.Color.End

:Echo.Color %1=Hex Color %2=String [%3=/n]
:# Temporarily disable expansion to preserve ! in the input string
setlocal disableDelayedExpansion
set "str=%~2"
:Echo.Color.2
setlocal enableDelayedExpansion
if defined LOGFILE %>>LOGFILE% <NUL set /P =!str!
:# Replace path separators in the string, so that the final path still refers to the current path.
set "str=a%ECHO.DEL%!str:\=a%ECHO.DEL%\..\%ECHO.DEL%%ECHO.DEL%%ECHO.DEL%!"
set "str=!str:/=a%ECHO.DEL%/..\%ECHO.DEL%%ECHO.DEL%%ECHO.DEL%!"
set "str=!str:"=\"!"
:# Go to the script directory and search for the trailing -
pushd "%ECHO.DIR%"
findstr /p /r /a:%~1 "^^##-" "!str!\..\!ECHO.FILE!" nul
popd
:# Remove the name of this script from the output. (Dependant on its length.)
for /l %%n in (1,1,24) do if not "!ECHO.FILE:~%%n!"=="" <nul set /p "=%ECHO.DEL%"
:# Remove the other unwanted characters "\..\: ##-"
<nul set /p "=%ECHO.DEL%%ECHO.DEL%%ECHO.DEL%%ECHO.DEL%%ECHO.DEL%%ECHO.DEL%%ECHO.DEL%%ECHO.DEL%%ECHO.DEL%"
:# Append the optional CRLF
set "TAIL=%3"
if defined TAIL echo.%~3&if defined LOGFILE %>>LOGFILE% echo.%~3
endlocal & endlocal & goto :eof

:Echo.Color.Var %1=Color %2=StrVar [%3=/n]
if not defined %~2 goto :eof
setlocal enableDelayedExpansion
set "str=!%~2!"
goto :Echo.Color.2

:Echo.Color.Init
set "ECHO.COLOR=call :Echo.Color"
set "ECHO.DIR=%~dp0"
set "ECHO.FILE=%~nx0"
:# Use prompt to store a backspace into a variable. (Actually backspace+space+backspace)
for /F "tokens=1 delims=#" %%a in ('"prompt #$H# & echo on & for %%b in (1) do rem"') do set "ECHO.DEL=%%a"
goto :eof

:#----------------------------------------------------------------------------#

:Echo.OK	[%1=Suffix string] [%2=/n]
%ECHO.COLOR% 0A "[OK]%~1" %2
goto :eof

:Echo.Success	[%1=Suffix string] [%2=/n]
%ECHO.COLOR% 0A "[Success]%~1" %2
goto :eof

:Echo.Warning	[%1=Suffix string] [%2=/n]
%ECHO.COLOR% 0E "[Warning]%~1" %2
goto :eof

:Echo.Failure	[%1=Suffix string] [%2=/n]
%ECHO.COLOR% 0C "[Failure]%~1" %2
goto :eof

:Echo.Wrong	[%1=Suffix string] [%2=/n]
%ECHO.COLOR% 0C "[Wrong]%~1" %2
goto :eof

:Echo.Color.End

:#----------------------------------------------------------------------------#

:TrimRightSlash %1=VARNAME
%FUNCTION% EnableDelayedExpansion
set "VARNAME=%~1"
%UPVAR% %VARNAME%
set "%VARNAME%=!%VARNAME%!::" &:# Note that :: cannot appear in a pathname
set "%VARNAME%=!%VARNAME%:\::=::!"
set "%VARNAME%=!%VARNAME%:::=!"
%RETURN%

:#----------------------------------------------------------------------------#
:#                                                                            #
:#  Function        FindPython                                                #
:#                                                                            #
:#  Description     Find the latest python.exe in %SEARCHDRIVES%              #
:#                                                                            #
:#  Note            Stop searching if found one Python on the first C: drive. #
:#                                                                            #
:#  History                                                                   #
:#   2010-05-31 JFL Created this routine for Tcl.                             #
:#   2017-01-13 JFL Adapted to Python, with an optional version.              #
:#   2017-01-16 JFL Added argument %2=VARNAME.                                #
:#                                                                            #
:#----------------------------------------------------------------------------#

:FindPython %1=Optional Python version. Ex: 27 or *. Default ""=* %2=VARNAME. Default=Display all
%FUNCTION% EnableExtensions EnableDelayedExpansion

:# Search in the list of drives, then in the possible \Python program directories.
set "EXE="			&:# Executable pathname
set "VER=%~1"			&:# Acceptable version suffix
if not defined VER set "VER=*"
set "ALL="
if "%VER%"=="*" set "ALL=1"
set "RETVAR=%~2"		&:# Variable where to store the result

if defined RETVAR %UPVAR% %RETVAR%

for %%d in (%SEARCHDRIVES%) do (
  for %%p in ("" "\Program Files" "\Program Files (x86)") do (
    for /d %%b in ("%%d:%%~p\Python%VER%") do (
      %ECHO.D% :# Looking in %%b
      if exist "%%~b\python.exe" (
      	set "EXE=%%~b\python.exe"
      	if not defined RETVAR %ECHO% !EXE!
      )
    )
    if not defined ALL if defined EXE ( :# The one that remains is the latest version found
      goto :FindPython.done
    )
  )
  if defined RETVAR if defined EXE ( :# Don't search on network drives if a local Python was found
    goto :FindPython.done
  )
)
:FindPython.done
if defined RETVAR set "%RETVAR%=%EXE%"
%RETURN%

:#----------------------------------------------------------------------------#
:#                                                                            #
:#  Function        Setup                                                     #
:#                                                                            #
:#  Description     Setup Windows for running *.py with the latest python.exe #
:#                                                                            #
:#  Note                                                                      #
:#                                                                            #
:#  History                                                                   #
:#   2010-05-31 JFL Created this routine.                                     #
:#   2011-09-06 JFL Setup now associates .py->python and .tk->wish.           #
:#                  Added a test mode distinct from the setup mode.           #
:#   2012-04-23 JFL Setup now updates environment variable PATHEXT if needed. #
:#                                                                            #
:#----------------------------------------------------------------------------#

:Setup %1=Optional Python version
%FUNCTION%
:# First check administrator rights
ren %SystemRoot%\win.ini win.ini >NUL 2>&1
if errorlevel 1 (
  >&2 %ECHO% Error: This must be run as Administrator.
  %RETURN% 1
)
%UPVAR% PATH
%UPVAR% PATHEXT
call :DoSetup setup %1
%RETURN%

:TestSetup %1=Optional Python version
%FUNCTION%
call :DoSetup test %1
if not errorlevel 1 (
  echo.
  if .%NEEDSETUP%.==.0. (
    %ECHO% The setup is good.
  ) else (
    %ECHO% The setup must be updated. Run this script again with option -s.
  )
)
%RETURN%

:# ----------------------------------------------------------------------------

:# Common routine for test and setup.
:DoSetup %1=setup|test %2=Optional Python version
%FUNCTION% EnableExtensions EnableDelayedExpansion
set MODE=%~1
set VER=%~2

:# Locate the latest Python shell
call :FindPython "%VER%" PYTHON
echo.
if "%PYTHON%"=="" (
  >&2 %ECHO% Failure. No Python shell found.
  %RETURN% 1
)
%ECHO% The Python shell is: "%PYTHON%"

:# Find the shell's directory
for %%B in ("%PYTHON%") do set "PYTHONBIN=%%~dpB" &:# Deduce the Python bin path
call :TrimRightSlash PYTHONBIN &:# Remove the trailing \ in that path

%UPVAR% PATH
%UPVAR% PATHEXT
%UPVAR% NEEDSETUP

:# First configure the Python text mode interpreter
%ECHO%
set PYTHONCMD="%PYTHON%" "%%1" %%*
call :Test1Setup py PYTHON PYTHONCMD Python.File

:# Make sure the local PATH includes the Python's bin directory.
:# (It is set globally by ActivePython's setup, but not locally in each open cmd window.)
:# Actually don't believe just the PATH, but do run Python, and see which instance starts, if any.
:# This is because I've seen cases where a non-python script ahead in the PATH overrides the apparent PATH order.
:# Now check if that path is present in the local PATH
set "PATH1=;%PATH%;"
set "PATH2=!PATH1:;%PYTHONBIN%\;=;!"	&:# Some versions append a trailing \.
set "PATH2=!PATH2:;%PYTHONBIN%;=;!"	&:# Others do not.
:# Also check if the right python.exe starts
set CMD=python -c "import sys; print (sys.executable)"
%ECHO.V% !CMD!
%ECHO% Verifying that "%PYTHON%" is accessible in the PATH
set "PYEXE="
for /f "delims=" %%e in ('!CMD! 2^>NUL') do set "PYEXE=%%e"
%ECHOVARS.D% PYEXE
if "%PATH1%"=="%PATH2%" ( :# If the python dir is not in the path
  if %MODE%==test (
    :# set CMD=python -c "import sys; print (str(sys.version_info.major) + str(sys.version_info.minor))"
    :# set CMD=python -c "import sys; import os.path; print (os.path.dirname(sys.executable))"
    if not defined PYEXE (
      call :Echo.Wrong " "
      %ECHO% The python directory is missing in the local PATH.
      set "NEEDSETUP=1"
    ) else if "!PYEXE!"=="%PYTHON%" ( :# It's not in PATH, yet it runs!
      :# This does happen, if the user has a batch that runs Python, whereever it is
      call :Echo.Warning " "
      %ECHO% It's not in the local PATH, but a script seems to run the python.exe there.
    ) else ( :# It's not in PATH, and another version runs.
      call :Echo.Wrong " "
      %ECHO% "python" starts "!PYEXE!".
      set "NEEDSETUP=1"
    )
  )
  if %MODE%==setup (
    %ECHO% :# Adding "%PYTHONBIN%" to the local PATH
    %EXEC% set "PATH=%PYTHONBIN%;%PATH%"
  )
) else ( :# The python.exe directory is in the path
  :# if %MODE%==test (
    :# set CMD=python -c "import sys; print (str(sys.version_info.major) + str(sys.version_info.minor))"
    :# set CMD=python -c "import sys; import os.path; print (os.path.dirname(sys.executable))"
    if "!PYEXE!"=="%PYTHON%" ( :# It's the right version that runs
      set "MSG="
      %IF_VERBOSE% set "MSG=It's there and it runs as expected"
      call :Echo.OK " "
      %ECHO% !MSG!
    ) else ( :# It is in the PATH, but another version runs.
      call :Echo.Wrong " "
      %ECHO% "python" starts "!PYEXE!".
      set "NEEDSETUP=1"
    )
  :# )
  if %MODE%==setup if not "!PYEXE!"=="%PYTHON%" (
    %ECHO% :# Moving "%PYTHONBIN%" ahead of the local PATH
    set "PATH1=;!PATH!;"
    set "PATH1=!PATH1:;%PYTHONBIN%\;=;!"	&:# Some versions append a trailing \.
    set "PATH1=!PATH1:;%PYTHONBIN%;=;!"		&:# Others do not.
    %EXEC% set "PATH=%PYTHONBIN%;!PATH1:~1,-1!"
  )
)

%RETURN% 0

:# ----------------------------------------------------------------------------

:Test1Setup	%1=Extension %2=.exe variable %3=Script startup command variable %4=Class
%FUNCTION% EnableExtensions EnableDelayedExpansion
set EXT=%1
set SH=!%2!
set CMD=!%3!
set DEFCLASS=%4
set NEEDSETUP=0

%UPVAR% PATHEXT
%UPVAR% NEEDSETUP

:# Check the class associated with the .%EXT% extension
set CLASS=
for /f "delims== tokens=2" %%c in ('%XEXEC% -f assoc .%EXT%') do set CLASS=%%c
:# In case of error, assoc displays: "File association not found for extension .%EXT%"
if defined CLASS (
  %ECHO% The .%EXT% extension is associated with class: "%CLASS%"
  if "%CLASS%"=="%DEFCLASS%" (
    set "MSG="
    %IF_VERBOSE% set "MSG=The class is defined"
    call :Echo.OK " "
    %ECHO% !MSG!
  ) else (
    call :Echo.Warning " "
    %ECHO% A class is defined, but the one expected was: %DEFCLASS%
  )
) else (
  set CLASS=%DEFCLASS%
  :# if %MODE%==test (
    call :Echo.Wrong " "
    %ECHO% It should be associated with class: !CLASS!
    set "NEEDSETUP=1"
  :# )
  if %MODE%==setup ( :# Create one if needed
    %ECHO% Associating it with: !CLASS!
    %EXEC% assoc .%EXT%=!CLASS!
  )
)

:# Check the open command associated with the class.
:# (Stored in HKEY_CLASSES_ROOT\%CLASS%\shell\open\command)
set CMD2=""
for /f "delims== tokens=2" %%c in ('%XEXEC% -f ftype %CLASS%') do set CMD2=%%c
if defined CLASS (
  %ECHO% The open command for class %CLASS% is: !CMD2:%%=%%%%!
  :# Note: Replace " with '' to make it a single string for the if command parser.
  if /I "%CMD2:"=''%" NEQ "%CMD:"=''%" (
    :# if %MODE%==test (
      call :Echo.Wrong " "
      %ECHO% It should be: !CMD:%%=%%%%!
      set "NEEDSETUP=1"
    :# )
    if %MODE%==setup (
      %ECHO% :# Setting it to: !CMD:%%=%%%%!
      :# Note: Using delayed expansion to avoid issues with CMD paths containing parentheses.
      :# Note: Don't use %EXEC% because it expands %1 and %*
      set CHGCMD=ftype %CLASS%=!CMD!
      %ECHO.XVD% !CHGCMD:%%=%%%%!
      %IF_EXEC% (
      	>NUL !CHGCMD!
        call :CheckError !ERRORLEVEL!
      )
    )
  ) else (
    set "MSG="
    %IF_VERBOSE% set "MSG=The command is correct"
    call :Echo.OK " "
    %ECHO% !MSG!
  )
)

:# Check the open command associated with the application
:# (Stored in HKEY_CLASSES_ROOT\Applications\%EXE%\shell\open\command)
for %%P in (%SH%) do set EXE=%%~nxP
set KEY="HKEY_CLASSES_ROOT\Applications\%EXE%\shell\open\command"
set CMD3=
for /f "skip=2 tokens=2,*" %%A in ('%XEXEC% -f reg query %KEY% 2">"NUL') do set CMD3=%%B
:# Note: Replace " with '' to make it a single string for the if command parser.
set "'CMD3'=%CMD3%"
if defined CMD3 set "'CMD3'=%CMD3:"=''%"
set "'CMD'=%CMD:"=''%"
%ECHOVARS.D% CMD 'CMD' CMD3 'CMD3'
if defined CMD3 (
  %ECHO% The open command for application %EXE% is: !CMD3:%%=%%%%!
  if /I "%'CMD3'%" EQU "%'CMD'%" ( :# It's the command we expected
    set "MSG="
    %IF_VERBOSE% set "MSG=The command is correct"
    call :Echo.OK " "
    %ECHO% !MSG!
  ) else ( :# It's NOT the command we expected
    :# if %MODE%==test (
      call :Echo.Wrong " "
      %ECHO% It should be: !CMD:%%=%%%%!
      set "NEEDSETUP=1"
    :# )
    if %MODE%==setup (
      %ECHO% :# Setting it to: !CMD:%%=%%%%!
      :# Note: Using delayed expansion to avoid issues with PYTHONCMD paths containing parentheses.  
      :# Note: Don't use %EXEC% because it expands %1 and %*
      set CHGCMD=reg add %KEY% /f /t REG_SZ /d "!CMD:"=\"!"
      %ECHO.XVD% !CHGCMD:%%=%%%%!
      %IF_EXEC% (
	>NUL !CHGCMD!
	call :CheckError !ERRORLEVEL!
      )
    )
  )
) else ( :# CMD3 is not defined
  %ECHO% The open command for application %EXE% is undefined
  set "MSG="
  %IF_VERBOSE% set "MSG=It's optional, but might be set to: !CMD:%%=%%%%!"
  call :Echo.OK " "
  %ECHO% !MSG!
)

:# Check the InstallPath registration, used by some extensions for locating Python
:# set CMD="%PYTHON%" -c "import sys; print (str(sys.version_info.major) + '.' + str(sys.version_info.minor))"
:# for /f %%v in ('!CMD!') do set PYVER=%%v
:# Can't make the above to work, due to the sub cmd.exe removing quotes we need.
for /f "tokens=2" %%v in ('%XEXEC% -f "%PYTHON%" -V 2">""&"1') do set PYVER=%%v
%ECHO.D% Python version %PYVER%
for /f "tokens=1,2 delims=." %%v in ("%PYVER%") do set PYVER=%%v.%%w
%ECHO.D% Python version %PYVER%
set "KEY=HKLM\SOFTWARE\Python\Pythoncore\%PYVER%\InstallPath"
set "InstallPath="
for /f "tokens=2,*" %%p in ('%XEXEC% -f reg query "%KEY%" /ve 2">"NUL ^| findstr REG_SZ') do set "InstallPath=%%q"
%ECHO% The Python InstallPath registration is: "%InstallPath%"
call :TrimRightSlash InstallPath &:# Remove the trailing \ in that path
if "%InstallPath%"=="%PYTHONBIN%" (
  set "MSG="
  %IF_VERBOSE% set "MSG=The InstallPath registration is correct"
  call :Echo.OK " "
  %ECHO% !MSG!
) else (
  :# if %MODE%==test (
    call :Echo.Wrong " "
    %ECHO% It should be: "%PYTHONBIN%\"
  :# )
  if %MODE%==setup (
    %ECHO% :# Updating the InstallPath registration to: "%PYTHONBIN%\"
    :# Note: The double \\ in the end is necessary for reg.exe, else one \ would escape the "
    %EXEC% reg add "%KEY%" /d "%PYTHONBIN%\\" /f
  )
)

:# Check the PythonPath registration, used by some Python extensions
set "KEY=HKLM\SOFTWARE\Python\Pythoncore\%PYVER%\PythonPath"
set "PythonPath="
for /f "tokens=2,*" %%p in ('%XEXEC% -f reg query "%KEY%" /ve 2">"NUL ^| findstr REG_SZ') do set "PythonPath=%%q"
%ECHO% The Python PythonPath registration is: "%PythonPath%"
set "PythonPath2="
if defined PythonPath set "PythonPath2=!PythonPath:%PYTHONBIN%=!"
if not "%PythonPath%"=="%PythonPath2%" (
  set "MSG="
  %IF_VERBOSE% set "MSG=The PythonPath registration is correct"
  call :Echo.OK " "
  %ECHO% !MSG!
) else (
  set "PythonPath2=%PYTHONBIN%\;%PYTHONBIN%\Lib\;%PYTHONBIN%\DLLs\"
  :# if %MODE%==test (
    call :Echo.Wrong " "
    %ECHO% It should be: "!PythonPath2!"
  :# )
  if %MODE%==setup (
    %ECHO% :# Updating the PythonPath registration to: "!PythonPath2!"
    :# Note: The extra \ in the end is necessary for reg.exe, else one \ would escape the "
    %EXEC% reg add "%KEY%" /d "!PythonPath2!\" /f
  )
)

:# Check Explorer .py File Extension User Choice. (Which overrides the above if present)
:# Note that as we're running this as Administator, HKCU refers to the Administrator, NOT to the current user.
set "HKU[%USERNAME%]=HKCU"
set "USERS=%USERNAME%"
:# Repeat for the logged in user, if it's not the administrator
for /f "tokens=2" %%u in ('%XEXEC% -f query session ^| findstr /R "^>"') do set "USER=%%u"
if not "!USER!"=="%USERNAME%" (
  set "SID="
  for /f "tokens=1,2 skip=1" %%r in ('%XEXEC% -f wmic useraccount get name^,sid ^| findstr "S"') do if "%%r"=="!USER!" set "SID=%%s"
  if defined SID (
    set "HKU[!USER!]=HKU\!SID!"
    set "USERS=!USERS! !USER!"
  ) else (
    >&2 echo Error: Can't find the SID for user !USER!
  )
)
for %%u in (!USERS!) do (
  set "Progid="
  set "KEY=!HKU[%%u]!\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.py\UserChoice"
  set "USER=%%u"
  for /f "tokens=2,*" %%p in ('%XEXEC% -f reg query "!KEY!" /v Progid 2">"NUL ^| findstr REG_SZ') do set "Progid=%%q"
  if defined Progid (
    %ECHO% The Windows Explorer .py File Extension !USER! User Choice is: "!Progid!"
    if /I "!Progid!" equ "!CLASS!" goto :UserChoiceIsCorrect
    :# if %MODE%==test (
      call :Echo.Wrong " "
      %ECHO% It should be set to "!CLASS!" or deleted
      set "NEEDSETUP=1"
    :# )
    if %MODE%==setup (
      %ECHO% :# Removing Windows Explorer .py File Extension !USER! User Choice
      :# Note: The extra \ in the end is necessary for reg.exe, else one \ would escape the "
      %EXEC% reg delete "!KEY!" /f
    )
  ) else (
    %ECHO% The Windows Explorer .py File Extension !USER! User Choice is undefined
:UserChoiceIsCorrect
    set "MSG="
    %IF_VERBOSE% set "MSG=The Windows Explorer .py File Extension !USER! User Choice is correct"
    call :Echo.OK " "
    %ECHO% !MSG!
  )
)

:# Check the PATHEXT variable
:# 1) The global variable in the registry
set "KEY=HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
for /f "tokens=3" %%p in ('%XEXEC% -f reg query "%KEY%" /v PATHEXT ^| findstr REG_SZ') do @set PE=%%p
%ECHO% The global environment variable PATHEXT is: %PE%
set "PEXTOK=0"
for %%e in (%PE:;= %) do @if /i %%e==.%EXT% set "PEXTOK=1"
if %PEXTOK%==0 (
  :# if %MODE%==test (
    call :Echo.Wrong " "
    %ECHO% The .%EXT% extension is missing in the global PATHEXT.
    set "NEEDSETUP=1"
  :# )
  if %MODE%==setup (
    %ECHO% :# Updating global environment variable PATHEXT to: %PE%;.%EXT%
    %EXEC% reg add "%KEY%" /v PATHEXT /d "%PE%;.%EXT%" /f
    %ECHO% :# Notifying all windows of the environment block change
    :# The ^) below is necessary to prevent the ) from closing the if block ... v
    %ECHO.XVD% C# SendMessage(HWND_BROADCAST, WM_SETTINGCHANGE, 0, "Environment"^);
    :# Run a second instance of this script in PowerShell, to do the broadcast
    %IF_EXEC% PowerShell -c "Invoke-Expression $([System.IO.File]::ReadAllText('%SFULL%'))"
  )
) else (
  set "MSG="
  %IF_VERBOSE% set "MSG=The global PATHEXT is correct"
  call :Echo.OK " "
  %ECHO% !MSG!
)
:# 2) The local variable in the command shell
%ECHO.V% echo %%%%PATHEXT%%%%
%ECHO% The local environment variable PATHEXT is: %PATHEXT%
set "PEXTOK=0"
for %%e in (%PATHEXT:;= %) do @if /i %%e==.%EXT% set "PEXTOK=1"
if %PEXTOK%==0 (
  :# if %MODE%==test (
    call :Echo.Wrong " "
    %ECHO% The .%EXT% extension is missing in the local PATHEXT.
    set "NEEDSETUP=1"
  :# )
  if %MODE%==setup (
    %ECHO% :# Updating local environment variable PATHEXT to: %PATHEXT%;.%EXT%
    set "PATHEXT=%PATHEXT%;.%EXT%"
  )
) else (
  set "MSG="
  %IF_VERBOSE% set "MSG=The local PATHEXT is correct"
  call :Echo.OK " "
  %ECHO% !MSG!
)

%RETURN%

:CheckError
setlocal
set ERR=%1
set "INDENT=%INDENT%  "
%ECHO.D% exit %1
set "INDENT=%INDENT:~2%"
%IF_VERBOSE% %IF_EXEC% (
  if .%ERR%.==.0. (
    %ECHO% OK
  ) else (
    %ECHO% ERR=%ERR%
  )
)
exit /b %1

:#----------------------------------------------------------------------------#
:#                                                                            #
:#  Function        Main                                                      #
:#                                                                            #
:#  Description     Main routine                                              #
:#                                                                            #
:#  Note                                                                      #
:#                                                                            #
:#  History                                                                   #
:#   2010-04-02 JFL Created this routine.                                     #
:#                                                                            #
:#----------------------------------------------------------------------------#

:Help
echo.
echo Usage: %SCRIPT% [options] [N]
echo.
echo Options:
echo   -?        Display this help
echo   -l        List all installed instances of python.exe
echo   -s [N]    Setup Windows for running .py scripts with the latest python
echo   -t [N]    Test the current setup. (Default). Tells if it's useful to use -s.
echo   -v        Display verbose information
echo   -V        Display this script version
echo   -X        Display the setup commands, but do not run them.
echo.
echo Optional arguments
echo   N         Python version to use. Ex: 27 for Python27. Default: the latest.
goto :EOF

:Main
set "SEARCHDRIVES=C U"		&:# List of drives where to search for python.exe.
set "PYTHONVER="		&:# Version to use. Default: The most recent one
set "ACTION="
set ">DEBUGOUT=>&2"	&:# Send debug output to stderr, so that it does not interfere with subroutines output capture
goto getarg

:# Process the command line options
:nextarg
shift
:getarg
if not defined ARGS set "ARG=" & set ""ARG"=" & goto :Start
%POPARG%
if "!ARG!"=="-?" goto Help
if "!ARG!"=="/?" goto Help
if "!ARG!"=="-d" call :Debug.On & call :Verbose.On & goto nextarg
if "!ARG!"=="-l" set "ACTION=FindPython" & goto nextarg
if "!ARG!"=="-r" set "ACTION=RunPython" & goto nextarg
if "!ARG!"=="-s" set "ACTION=Setup" & goto nextarg
if "!ARG!"=="-t" set "ACTION=TestSetup" & goto nextarg
if "!ARG!"=="-tb" set "ACTION=TestBroadcast" & goto nextarg
if "!ARG!"=="-tc" set "ACTION=TestColors" & goto nextarg
if "!ARG!"=="-v" call :Verbose.On & goto nextarg
if "!ARG!"=="-V" (echo %VERSION%) & goto :eof
if "!ARG!"=="-X" call :Exec.Off & goto nextarg
if "!ARG:0,1!"=="-" >&2 echo Error: Unrecognized switch: %1 & goto nextarg
if not defined PYTHONVER set "PYTHONVER=%~1" & goto nextarg
>&2 echo Error: Unrecognized argument: %1
goto nextarg

:# Execute the selected action
:Start
if not defined ACTION set "ACTION=TestSetup"
%ECHOVARS.D% ACTION PYTHONVER
call :%ACTION% %PYTHONVER%
if "%ACTION%"=="Setup" endlocal & set "PATHEXT=%PATHEXT%" & set "PATH=%PATH%"
exit /b

:# Locate and start the Python interpreter
:RunPython
set ">NUL=>NUL"
%IF_DEBUG% set ">NUL="
call :FindPython "%~1" PYTHON %>NUL%
if not defined PYTHON (
  echo>&2 Failed. No python interpreter found.
  exit /b 1
)
:# Start it
"%PYTHON%" %*
goto :eof

:# Test color messages
:TestColors
call :Echo.OK " "
%ECHO% This is good
call :Echo.Warning " "
%ECHO% Be careful
call :Echo.Wrong " "
%ECHO% This is bad
exit /b

:# Test the WM_SETTINGCHANGE broadcast
:TestBroadcast
:# Run a second instance of this script in PowerShell, to do the broadcast
:# This first command is simpler, but does not work in all versions of PowerShell
:# type %ARG0% | PowerShell -c -
:# Instead, use this one that works from Win7/PSv2 to Win10/PSv5
PowerShell -c "Invoke-Expression $([System.IO.File]::ReadAllText('%SFULL%'))"
exit /b

:# End of the PowerShell comment section protecting the batch section.
#>

# PowerShell subroutine called from the batch setup routine

# Redefine the colors for a few message types
$colors = (Get-Host).PrivateData
if ($colors) { # Exists for ConsoleHost, but not for ServerRemoteHost
  $colors.VerboseForegroundColor = "white"	# Less intrusive than the default yellow
  $colors.DebugForegroundColor = "cyan"		# Distinguish debug messages from yellow warning messages
}

# Inherit the DEBUG mode from the batch instance
if ($env:DEBUG -eq 1) {
  $Debug = $true
  $DebugPreference = "Continue"		# Make sure Write-Debug works
} else {
  $Debug = $false
  $DebugPreference = "SilentlyContinue"	# Write-Debug does nothing
}

Write-Debug "# This is PowerShell, broadcasting WM_SETTINGCHANGE for the Environment"

# import sendmessagetimeout from win32
add-type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
  [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
  public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
    uint fuFlags, uint uTimeout, out UIntPtr lpdwResult
  );
"@

function Invoke-WMSettingsChanged {
  $HWND_BROADCAST = [intptr]0xffff;
  $WM_SETTINGCHANGE = 0x1a;
  $result = [uintptr]::zero
  # notify all windows of environment block change
  $done = [win32.nativemethods]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE,
	    [uintptr]::Zero, "Environment", 2, 5000, [ref]$result);
  return $done # 0=Failed. Check GetLastError(); !0=Success
}

$done = Invoke-WMSettingsChanged

return

# The following line, used by :Echo.Color, must be last and not end by a CRLF.
##-