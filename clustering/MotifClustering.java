package projects.pwmbench;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.FilenameFilter;
import java.io.IOException;
import java.text.DecimalFormat;
import java.util.Arrays;
import java.util.Date;
import java.util.HashSet;
import java.util.LinkedList;

import de.jstacs.DataType;
import de.jstacs.clustering.distances.DistanceMetric;
import de.jstacs.clustering.distances.SequenceScoreDistance;
import de.jstacs.clustering.hierachical.ClusterTree;
import de.jstacs.clustering.hierachical.Hclust;
import de.jstacs.clustering.hierachical.Hclust.Linkage;
import de.jstacs.data.alphabets.DNAAlphabet;
import de.jstacs.data.alphabets.DNAAlphabetContainer;
import de.jstacs.parameters.EnumParameter;
import de.jstacs.parameters.FileParameter;
import de.jstacs.parameters.Parameter;
import de.jstacs.parameters.ParameterException;
import de.jstacs.parameters.SimpleParameter;
import de.jstacs.parameters.SimpleParameter.DatatypeNotValidException;
import de.jstacs.parameters.validation.NumberValidator;
import de.jstacs.results.CategoricalResult;
import de.jstacs.results.ListResult;
import de.jstacs.results.NumericalResult;
import de.jstacs.results.PlotGeneratorResult;
import de.jstacs.results.PlotGeneratorResult.PlotGenerator;
import de.jstacs.results.Result;
import de.jstacs.results.ResultSet;
import de.jstacs.results.ResultSetResult;
import de.jstacs.results.TextResult;
import de.jstacs.results.savers.PlotGeneratorResultSaver;
import de.jstacs.results.savers.PlotGeneratorResultSaver.Format;
import de.jstacs.sequenceScores.statisticalModels.StatisticalModel;
import de.jstacs.sequenceScores.statisticalModels.trainable.PFMWrapperTrainSM;
import de.jstacs.tools.JstacsTool;
import de.jstacs.tools.ProgressUpdater;
import de.jstacs.tools.Protocol;
import de.jstacs.tools.ToolParameterSet;
import de.jstacs.tools.ToolResult;
import de.jstacs.tools.ui.cli.CLI;
import de.jstacs.utils.ComparableElement;
import de.jstacs.utils.Pair;
import de.jstacs.utils.SeqLogoPlotter.SeqLogoPlotGenerator;
import projects.motifComp.MotifTreePlotter;
import projects.motifComp.MotifTreePlotter.MotifTreePlotGenerator;

public class MotifClustering implements JstacsTool {

	public static void main(String[] args) throws Exception{
		CLI cli = new CLI(new MotifClustering());
		
		cli.run(args);
	}
	
	@Override
	public ToolParameterSet getToolParameters() {
		
		LinkedList<Parameter> pars = new LinkedList<>();
		try {
			pars.add(new SimpleParameter(DataType.STRING, "PWM path", "the path to a folder holding PWMs in cisBP format", true));
			pars.add(new SimpleParameter(DataType.INT,"k","the length of the k-mers used for the De-Bruijn sequence",true,new NumberValidator<Integer>(5, 12),10));
			pars.add(new SimpleParameter(DataType.DOUBLE,"cutoff","cutoff for separating sub-trees",false,new NumberValidator<Double>(0.0,Double.POSITIVE_INFINITY)));
			pars.add(new SimpleParameter(DataType.BOOLEAN,"heights","show labels indicating heights of inner nodes",true,false));
			pars.add(new SimpleParameter(DataType.STRING,"prefix","prefix of the output trees and clusters",true,"TF_"));
			pars.add(new EnumParameter(PlotGeneratorResultSaver.Format.class, "the output format", true));
		} catch (DatatypeNotValidException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (ParameterException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		
		return new ToolParameterSet(this.getShortName(), pars.toArray(new Parameter[0]));
		
	}

	private Pair<PFMWrapperTrainSM[],double[][][]> readMotifs(String motifDir) throws CloneNotSupportedException, IOException{
		File[] motifs = (new File(motifDir)).listFiles(new FilenameFilter() {
			
			@Override
			public boolean accept(File dir, String name) {
				return name.endsWith(".pcm") || name.endsWith(".ppm");
			}
		});
		Arrays.sort(motifs);
		
		PFMWrapperTrainSM[] pwms = new PFMWrapperTrainSM[motifs.length];
		double[][][] pfms = new double[motifs.length][][];
		for(int i=0;i<motifs.length;i++){
			
			BufferedReader read = new BufferedReader(new FileReader(motifs[i]));
			
			LinkedList<double[]> li = new LinkedList<>();
			
			String str = read.readLine();
			String name = str.substring(1).trim();
			
			double ess = 4E-4;
			if(motifs[i].getName().endsWith(".pcm")) {
				ess = 4.0;
			}
			
			while( (str = read.readLine()) != null ){
				if(str.trim().length() == 0){
					break;
				}
				String[] parts = str.split("\t");
				double[] row = new double[parts.length];
				for(int j=0;j<parts.length;j++){
					row[j] = Double.parseDouble(parts[j]);
				}
				li.add(row);
			}
			read.close();
			double[][] pfm = li.toArray(new double[0][]);
			pfms[i] = pfm;
			PFMWrapperTrainSM pwm = new PFMWrapperTrainSM(DNAAlphabetContainer.SINGLETON, name, pfm, ess);
			pwms[i] = pwm;
			
		}
		
		return new Pair<PFMWrapperTrainSM[], double[][][]>(pwms, pfms);
	}
	
	private String toString(String name, double[][] rep){
		StringBuffer sb = new StringBuffer();
		sb.append(">"+name+"\n");
		for(int i=0;i<rep.length;i++){
			//sb.append((i+1));
			for(int j=0;j<rep[i].length;j++){
				if(j > 0) {
					sb.append("\t");
				}
				sb.append(rep[i][j]);
			}
			sb.append("\n");
		}
		sb.append("\n");
		return sb.toString();
	}
	
	private String findRepresentative(double[][] distMat, PFMWrapperTrainSM[] pwms, LinkedList<ResultSet> coll, HashSet<String> usedIds){
		
		if(usedIds != null && usedIds.size() == 1){
			String id = usedIds.iterator().next();
			coll.add(new ResultSet(new Result[]{
					new CategoricalResult("ID", "", id),
					new NumericalResult("Avg. correlation", "", 0.0)}));
			return id;
		}
		
		double[] sums = new double[distMat.length];
		for(int i=0;i<distMat.length;i++){
			for(int j=0;j<distMat.length;j++){
				if(usedIds == null || (usedIds.contains(pwms[i].getName()) && usedIds.contains(pwms[j].getName()))){
					if(j<i){
						//System.out.println("a: "+pwms[i].getName()+" "+pwms[j].getName()+" "+distMat[i][j]);
						sums[i] += 1.0-distMat[i][j];
					}else if(j>i){
						//System.out.println("b: "+pwms[i].getName()+" "+pwms[j].getName()+" "+distMat[j][i]);
						sums[i] += 1.0-distMat[j][i];
					}
				}
			}
			sums[i] /= (usedIds == null ? distMat.length : usedIds.size())-1;
			if(usedIds == null || usedIds.contains(pwms[i].getName())){
				coll.add(new ResultSet(new Result[]{
						new CategoricalResult("ID", "", pwms[i].getName()),
						new NumericalResult("Avg. correlation", "", sums[i])
				}));
			}
		}
		
		int idx = -1;
		double max = Double.NEGATIVE_INFINITY;
		for(int i=0;i<sums.length;i++){
			if(usedIds == null || usedIds.contains(pwms[i].getName())){
				if(sums[i] > max){
					max = sums[i];
					idx = i;
				}
			}
		}
		
		String minId = pwms[ idx ].getName();
		
		return minId; 
	}
	
	
	@Override
	public ToolResult run(ToolParameterSet parameters, Protocol protocol, ProgressUpdater progress, int threads)
			throws Exception {
		String motifDir = (String) parameters.getParameterAt(0).getValue();
		int k = (int) parameters.getParameterAt(1).getValue();
		Double cutoff = null;
		if(parameters.getParameterAt(2).hasDefaultOrIsSet()){
			cutoff = (Double) parameters.getParameterAt(2).getValue();
		}
		boolean showHeights = (boolean) parameters.getParameterAt(3).getValue();
		String prefix = (String) parameters.getParameterAt(4).getValue();
		PlotGeneratorResultSaver.Format format = (Format) parameters.getParameterAt(5).getValue();
		
		Pair<PFMWrapperTrainSM[],double[][][]> pair = readMotifs(motifDir); 
		
		PFMWrapperTrainSM[] pwms = pair.getFirstElement();
		double[][][] pfms = pair.getSecondElement();
		
		DistanceMetric<StatisticalModel> dist = new SequenceScoreDistance(DNAAlphabet.SINGLETON, k, false);
		
		double[][] distMat = DistanceMetric.getPairwiseDistanceMatrix(dist, pwms);
		
		Hclust<StatisticalModel> hclust = new Hclust<StatisticalModel>(dist,Linkage.AVERAGE);
		
		ClusterTree<StatisticalModel> tree = hclust.cluster(distMat, pwms);
		tree.leafOrder(distMat);
		
		LinkedList<ResultSet> coll = new LinkedList<>();
		
		String minId = findRepresentative(distMat, pwms, coll, null);
		
		MotifTreePlotGenerator gen = new MotifTreePlotGenerator(tree, 400, k, minId, showHeights, cutoff);
		
		double[][] rep = gen.getRepresentative();
		
		LinkedList<Result> list = new LinkedList<>();
		
		PlotGeneratorResult plot = new PlotGeneratorResult("Full cluster tree", "", gen, true,format);
		list.add(plot);
		
		LinkedList<Result> repPWMs = new LinkedList<>();
		
		for(int i=0;i<pwms.length;i++){
			String myName = pwms[i].getName();
			if(myName.equals(minId)){
				repPWMs.add(new TextResult("Full_"+myName,"",new FileParameter.FileRepresentation("", toString("centroid",pfms[i])),"txt",this.getToolName(),null,true));
			}
		}
		
		if(cutoff != null){
			
			StringBuffer elementsAndClusters = new StringBuffer();
			
			
			ClusterTree<StatisticalModel>[] subtrees = Hclust.cutTree(cutoff, tree);
			
			ComparableElement<ClusterTree<StatisticalModel>, Integer>[] orderedTrees = new ComparableElement[subtrees.length];		
			for(int i=0;i<subtrees.length;i++){
				orderedTrees[i] = new ComparableElement<ClusterTree<StatisticalModel>, Integer>(subtrees[i], -subtrees[i].getNumberOfElements());
			}
			
			Arrays.sort(orderedTrees);
			
			DecimalFormat idFormat = new DecimalFormat("000");
			
			for(int i=0;i<orderedTrees.length;i++){
				
				String clusterID = prefix+idFormat.format(i+1);
				
				ClusterTree<StatisticalModel> subtree = orderedTrees[i].getElement();
				
				HashSet<String> names = new HashSet<>();
				
				StatisticalModel[] members = subtree.getClusterElements();
				for(int j=0;j<members.length;j++){
					names.add( ((PFMWrapperTrainSM)members[j]).getName() );
				}
				
				LinkedList<ResultSet> subColl = new LinkedList<>();
				
				String subMinId = findRepresentative(distMat, pwms, subColl, names);
				
				PlotGenerator pg = null;
				double[][] subrep = null;
				if(subtree.getNumberOfElements()==1){
					pg = new SeqLogoPlotGenerator( ((PFMWrapperTrainSM)subtree.getClusterElements()[0]).getPWM(),400);
				}else{
					pg = new MotifTreePlotGenerator(subtree, 400, k, subMinId, false, null);
					subrep = ((MotifTreePlotGenerator)pg).getRepresentative();
				}
				
				list.add(new PlotGeneratorResult(clusterID, "", pg, true,format));				
				
				if(subrep != null){

					String cutSubRep = toString("shortened consensus",MotifTreePlotter.cutDown(subrep));

					list.add(new ResultSetResult(clusterID+" supplement","",null,new ResultSet(new Result[]{
							new ListResult("Avg correlation", "", null, subColl),
							new TextResult("Consensus PWM", "", new FileParameter.FileRepresentation("", toString("consensus",subrep)), "txt", this.getToolName(), null, true),
							new TextResult("Shortened consensus PWM", "", new FileParameter.FileRepresentation("", cutSubRep), "txt", this.getToolName(), null, true)
					})));

				}
				
				for(int j=0;j<members.length;j++){
					String myName = ((PFMWrapperTrainSM)members[j]).getName();
					elementsAndClusters.append( myName + "\t" + clusterID + "\t" + (myName.equals(subMinId) ? "1" : "0")+"\n");
					
					if(myName.equals(subMinId)){
						double[][] pfm = null;
						for(int l=0;l<pwms.length;l++){
							if(pwms[l].getName().equals(myName)){
								pfm = pfms[l];
								break;
							}
						}
						
						
						repPWMs.add(new TextResult(clusterID+"_"+myName,"",new FileParameter.FileRepresentation("", toString(myName,pfm)),"txt",this.getToolName(),null,true));
					}
					
				}
				

			}
			
			

			list.add(new TextResult("Cluster assignments","", new FileParameter.FileRepresentation("", elementsAndClusters.toString()), "tsv", this.getToolName(), null, true));
		}
		
		list.add(new ResultSetResult("Motifs representative","",null,new ResultSet(repPWMs)));
		
		
		String fullRep = toString("full consensus",rep);
		String cutRep = toString("shortened full consensus",MotifTreePlotter.cutDown(rep));
		
		list.add(new ResultSetResult("Full supplement","",null,new ResultSet(new Result[]{
					new ListResult("Avg correlation", "", null, coll),
					new TextResult("Consensus PWM", "", new FileParameter.FileRepresentation("", fullRep), "txt", this.getToolName(), null, true),
					new TextResult("Shortened consensus PWM", "", new FileParameter.FileRepresentation("", cutRep), "txt", this.getToolName(), null, true)
		})));
		
		
		return new ToolResult("Result of "+getToolName(), "", null, new ResultSet(list), parameters, getToolName(), new Date());
	}

	@Override
	public String getToolName() {
		return "Motif clustering";
	}

	@Override
	public String getToolVersion() {
		return "0.2.1";
	}

	@Override
	public String getShortName() {
		return "motifClust";
	}

	@Override
	public String getDescription() {
		return "";
	}

	@Override
	public String getHelpText() {
		return "";
	}

	@Override
	public ResultEntry[] getDefaultResultInfos() {
		return null;
	}

	@Override
	public ToolResult[] getTestCases(String path) {
		return null;
	}

	@Override
	public void clear() {		
	}

	@Override
	public String[] getReferences() {
		return null;
	}
}
