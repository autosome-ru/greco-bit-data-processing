motifs = Dir.glob('data/all_motifs/*.{pcm,ppm}').sort
motifs.combination(2).each{|fn_1, fn_2|
  bn_1 = File.basename(fn_1)
  bn_2 = File.basename(fn_2)
  ext_1 = fn_1[-3,3]
  ext_2 = fn_2[-3,3]
  puts "java -cp ape.jar ru.autosome.macroape.EvalSimilarity #{fn_1} #{fn_2} --first-#{ext_1} --second-#{ext_2} | grep -Pe '^S\\t' | cut -d $'\\t' -f 2 | xargs -I{} echo -e '#{bn_1}\\t#{bn_2}\\t{}'"
}
