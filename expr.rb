require "rubygems"   
require "kanocc"

# ==================================================
# Define the token 'Number' and what it matches 

class Num < Kanocc::Token 
  attr_reader :val 
  pattern(/\d+/) { @val = @m[0].to_i} 
end
        
# ==================================================
# Define a grammar based on the nonterminals 'Expr', 
# 'Line' and 'Program' 

class Expr < Kanocc::Nonterminal 
  attr_reader :val 

  rule(Expr, "+", Expr) { @val = @rhs[0].val + @rhs[2].val}
  rule(Expr, "-", Expr) { @val = @rhs[0].val - @rhs[2].val}
  rule(Expr, "*", Expr) { @val = @rhs[0].val * @rhs[2].val}; prec 2
  rule(Expr, "/", Expr) { @val = @rhs[0].val / @rhs[2].val}; prec 2 
  rule("(", Expr, ")") { @val = @rhs[1].val} 
  rule(Num) { @val = @rhs[0].val} 
end

class Line < Kanocc::Nonterminal 
  rule(Expr, "\n") {puts @rhs[0].val.to_s} 
  rule(Kanocc::Error, "\n") do
    puts "Sorry - didn't understand #{@program.slice[@rhs.start_pos, @rhs.end_pos - @rhs.start_pos]}"
  end
end

class Program < Kanocc::Nonterminal 
  rule(Line, Program) 
  rule("exit", "\n") {puts "Goodbye!"} 
end

# ========== Set up a parser ====================== 
myParser = Kanocc::Kanocc.new(Program)

# ========== And try it out ======================= 
program = <<-EOT 
  3 + 4 - 2 
  8 - 2 * 3 
  8 * + 3 
  exit 
EOT

myParser.parse(program)
