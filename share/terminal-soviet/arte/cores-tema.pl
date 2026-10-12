#!/usr/bin/perl
# Terminal Soviético — adaptação das cores de uma arte do arttime à paleta do tema.
#
# Uso: artprint ... | cores-tema.pl
#
# Não remove códigos ANSI: reescreve só os PARÂMETROS DE COR das sequências SGR
# (ESC [ ... m), preservando texto, alinhamento, negrito, sublinhado, vídeo
# reverso etc. Cada cor (16 cores, 256 cores ou truecolor; frente e fundo) é
# convertida em um tom da rampa fósforo do tema, pela luminância, de modo que
# claro/escuro e o contraste do desenho se mantêm:
#
#   luminância 0  -> fundo do tema        (#101210)   [luminância com curva 0,65]
#   luminância Ya -> acento do tema       (#B8D58A, Ya = luminância do acento)
#   luminância 1  -> verde brilhante      (bright2 do tema, #D2E8AE)
#
# Cores 0-15 usam a paleta REAL do terminal (foot.ini do tema ativo), então a
# cor 2 (verde do tema), que o arttime usa para frases, vira o próprio acento.
# "Cor padrão" (SGR 0 e 39) passa a ser o acento, para a arte monocromática
# também ficar fósforo. Lê o tema ativo do Omarchy; sem ele, usa o soviet-terminal.
use strict; use warnings;

my $theme = "$ENV{HOME}/.local/state/omarchy/current/theme";
my %pal = (
  background => '101210', foreground => 'C8CBBF',
  regular0 => '101210', regular1 => 'BD4A42', regular2 => 'B8D58A', regular3 => 'C9B26B',
  regular4 => '7F9A88', regular5 => 'A27B76', regular6 => '8FB09A', regular7 => 'C8CBBF',
  bright0 => '444B42', bright1 => 'D2625A', bright2 => 'D2E8AE', bright3 => 'DCC88A',
  bright4 => '9FB8A6', bright5 => 'BE9A94', bright6 => 'AECBB8', bright7 => 'E2E5D8',
);
my $accent = 'B8D58A';
if (open my $fh, '<', "$theme/foot.ini") {
  while (<$fh>) { $pal{$1} = uc $2 if /^\s*(background|foreground|regular\d|bright\d)\s*=\s*([0-9A-Fa-f]{6})/ }
  close $fh;
}
if (open my $fh, '<', "$theme/colors.toml") {
  while (<$fh>) { $accent = uc $1 if /^\s*accent\s*=\s*"#([0-9A-Fa-f]{6})"/ }
  close $fh;
}

sub hex2rgb { my $h = shift; return map { hex } unpack '(A2)3', $h }
# Luminância (Rec. 709) com curva 0,65: o matiz some, então os tons médios sobem
# para o desenho não afundar no fundo; a ordem claro/escuro é mantida.
sub lum { my ($r, $g, $b) = @_; return ((0.2126 * $r + 0.7152 * $g + 0.0722 * $b) / 255) ** 0.65 }

my @bg = hex2rgb($pal{background});
my @ac = hex2rgb($accent);
my @hi = hex2rgb($pal{bright2});
my $ya = lum(@ac); $ya = 0.79 if $ya <= 0.05 || $ya >= 0.99;

my %memo;
sub ramp {   # (r,g,b) -> "38;2;R;G;B" sem o prefixo
  my $key = join ',', @_;
  return $memo{$key} //= do {
    my $y = lum(@_);
    my ($a, $b, $t) = $y <= $ya ? (\@bg, \@ac, $y / $ya) : (\@ac, \@hi, ($y - $ya) / (1 - $ya));
    join ';', map { int($a->[$_] + ($b->[$_] - $a->[$_]) * $t + 0.5) } 0 .. 2;
  };
}

my @base = map { [hex2rgb($pal{$_ < 8 ? "regular$_" : 'bright' . ($_ - 8)})] } 0 .. 15;
sub x256 {
  my $n = shift;
  return @{ $base[$n] } if $n < 16;
  if ($n < 232) { $n -= 16; return map { $_ ? 55 + 40 * $_ : 0 } int($n / 36), int($n / 6) % 6, $n % 6 }
  my $v = 8 + 10 * ($n - 232); return ($v, $v, $v);
}

my $DEF = '38;2;' . join(';', @ac);   # "cor padrão" no modo tema

sub sgr {
  my @p = split /;/, $_[0], -1;
  @p = ('0') unless @p;
  my @o;
  while (@p) {
    my $x = shift @p; $x = 0 if $x eq '';
    if ($x == 38 || $x == 48) {
      my $kind = $x == 38 ? 38 : 48;
      my $m = shift(@p) // '';
      if ($m eq '5' && @p) { push @o, "$kind;2;" . ramp(x256(shift @p)) }
      elsif ($m eq '2' && @p >= 3) { push @o, "$kind;2;" . ramp(splice @p, 0, 3) }
      else { push @o, $x, ($m eq '' ? () : $m) }
    }
    elsif ($x >= 30 && $x <= 37) { push @o, '38;2;' . ramp(@{ $base[$x - 30] }) }
    elsif ($x >= 90 && $x <= 97) { push @o, '38;2;' . ramp(@{ $base[$x - 82] }) }
    elsif ($x >= 40 && $x <= 47) { push @o, '48;2;' . ramp(@{ $base[$x - 40] }) }
    elsif ($x >= 100 && $x <= 107) { push @o, '48;2;' . ramp(@{ $base[$x - 92] }) }
    elsif ($x == 0) { push @o, '0', $DEF }
    elsif ($x == 39) { push @o, $DEF }
    else { push @o, $x }
  }
  return "\e[" . join(';', @o) . 'm';
}

binmode STDIN; binmode STDOUT;
local $/;
my $s = <STDIN> // '';
$s =~ s/\e\[([0-9;]*)m/sgr($1)/ge;
print "\e[$DEF" . "m" . $s;
