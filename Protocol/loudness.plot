set term epslatex size 4.5, 3.62 color colortext
set output "loudness.tex"
set xlabel '$\tilde{a}$'
set ylabel '$\tilde{N}$'
set format '$%g$'
set xrange [0:260]
set yrange [0:260]
set style line 1 lt 1 lw 3 pt 3 linecolor rgb "red"
set style line 2 lt 1 lw 5 pt 3 linecolor rgb "blue"
set key spacing 6
plot 255 - (4 - x/64)**4 title '$ 255 - \left(4 - \frac{\tilde{a}}{64}\right)^4 $', 255 - floor((255 - x)**2/64**2)**2 title '$ 255 - \left\lfloor{\frac{(255 - \tilde{a})^2}{64^2}}\right\rfloor^2 $'
