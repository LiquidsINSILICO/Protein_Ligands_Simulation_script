#!/bin/bash
#SBATCH -N 1
#SBATCH -A account_name              ## check access of the account to associated partition_Name
##SBATCH --job-name=job_name
#SBATCH -p partition_Name
#SBATCH --gres=gpu:1                ## specify the number of GPUS
#SBATCH -n 36                       ## total number of threads 
#SBATCH --mem-per-cpu=3000          ## check the requirement of memory for your system and assign the value in MB
#SBATCH --time=4-00:00:00           ## Time limit to run the job
##SBATCH --exclude=gnode[118]       ## specify node to exclude

module add u18/gromacs/2021.4-plumed2

gmx_mpi grompp -f ./mdp/minim_1.mdp -c complex_solv_ions.gro -p topol.top -o em.tpr -pp em -po em
gmx_mpi mdrun -v -deffnm em 
echo Potential | gmx_mpi energy -f em.edr -o potential.xvg
gmx_mpi grompp -f ./mdp/nvt.mdp -c em.gro -r em.gro -p topol.top -n index.ndx -o nvt.tpr -pp nvt -po nvt
gmx_mpi mdrun -v -deffnm nvt 
echo Temperature | gmx_mpi energy -f nvt.edr -o temperature.xvg
gmx_mpi grompp -f ./mdp/npt.mdp -c nvt.gro -t nvt.cpt -r nvt.gro -p topol.top -n index.ndx -o npt.tpr -pp npt -po npt
gmx_mpi mdrun -v -deffnm npt 
echo Pressure | gmx_mpi energy -f npt.edr -o pressure.xvg
echo Density | gmx_mpi energy -f npt.edr -o density.xvg
gmx_mpi grompp -f ./mdp/md-constraint.mdp -c npt.gro -t npt.cpt -p topol.top -n index.ndx -o md_0_10.tpr -pp md_0_10 -po md_0_10
gmx_mpi mdrun  -v -deffnm md_0_10
mv md_0_10.mdp md_0_10_1.mdp
mv md_0_10.tpr md_0_10_1.tpr
mv md_0_10.cpt md_0_10_1.part0001.cpt
mv md_0_10.log md_0_10_1.part0001.log
mv md_0_10.edr md_0_10_1.part0001.edr
mv md_0_10.gro md_0_10_1.part0001.gro
mv md_0_10.xtc md_0_10_1.part0001.xtc
mv md_0_10_prev.cpt md_0_10_1.part0001_prev.cpt
for i in 1
do
        let j=i+1
        gmx_mpi convert-tpr -s md_0_10_${i}.tpr -o md_0_10_${j}.tpr -extend 10000
        gmx_mpi mdrun  -cpi md_0_10_${i}.part000${i}.cpt -v -deffnm md_0_10_${j} -noappend -cpt 60 -cpo md_0_10_${j}.part000${j}.cpt
done
echo Finish = `date`
gmx_mpi trjcat -f md_0_10_1.part0001.xtc md_0_10_2.part0002.xtc -o md_20ns.xtc
gmx_mpi trjconv -f md_20ns.xtc -o md_20ns_nojump.xtc -pbc nojump
gmx_mpi trjconv -s md_0_10_1.tpr -f md_20ns.xtc -o md_0_10_center.xtc -center -pbc mol -ur compact << EOF
1
0
EOF
gmx_mpi trjconv -s md_0_10_1.tpr -f md_0_10_center.xtc -o After-20ns.pdb -dump 20000 -n index.ndx <<EOF
20
EOF
mkdir analysis
cd analysis
mkdir RMSF
cd RMSF
gmx_mpi rmsf -s ../../em.tpr -f ../../md_20ns_nojump.xtc -n ../../index.ndx -o rmsf_protein.xvg -res << EOF
1
EOF
cd ../
mkdir Rg
cd Rg
gmx_mpi gyrate -s ../../em.tpr -f ../../md_20ns_nojump.xtc -n ../../index.ndx -o protein_gyrate.xvg << EOF
1
EOF
cd ../
mkdir RMSD
cd RMSD
gmx_mpi rms -s ../../em.gro -f ../../md_20ns_nojump.xtc -o rmsd_protein_backbone.xvg << EOF
4
4
EOF
gmx_mpi rms -s ../../em.gro -f ../../md_20ns_nojump.xtc -o rmsd_L011_backbone.xvg -tu ns -n ../../index.ndx << EOF
4
22
EOF
gmx_mpi rms -s ../../em.gro -f ../../md_20ns_nojump.xtc -o rmsd_L021_backbone.xvg -tu ns -n ../../index.ndx << EOF
4
23
EOF
cd ../
mkdir Potential
cd Potential
cp ../../potential.xvg .
cd ../
mkdir H-bond
cd H-bond
gmx_mpi hbond -s ../../em.tpr -f ../../md_20ns_nojump.xtc -n ../../index.ndx -num hbnumLIG-WAT.xvg -hbn hbond_LIG-WAT.ndx << EOF
13
16
EOF
gmx_mpi hbond -s ../../em.tpr -f ../../md_20ns_nojump.xtc -n ../../index.ndx -num hbnum_BzCHO-Protein.xvg -hbn hbond_BzCHO-Protein.ndx << EOF
1
13
EOF
gmx_mpi hbond -s ../../em.tpr -f ../../md_20ns_nojump.xtc -n ../../index.ndx -num hbnum_EtNO2-Protein.xvg -hbn hbond_EtNO2-Protein.ndx << EOF
1
14
EOF
cd ../
mkdir SASA
cd SASA
gmx_mpi sasa -s ../../em.tpr -f ../../md_20ns_nojump.xtc -n ../../index.ndx -o sasa_run.xvg -surface Protein
cd ../
mkdir Interaction_Dynamics
cd Interaction_Dynamics
gmx_mpi covar -f ./../../md_20ns_nojump.xtc -s ./../../md_0_10_1.tpr -n ./../../index.ndx -o eiginval.xvg << EOF
3
3
EOF
gmx_mpi anaeig -v eigenvec.trr -s ../../em.tpr -f ../../md_20ns_nojump.xtc -n ../../index.ndx -comp comp.xvg -rmsf eigrmsf.xvg -2d 2d.xvg -first 1 -last 2 << EOF
3
3
EOF

cd ../
mkdir MMPBSA
cd MMPBSA
mkdir LIG-1_Protein
cd LIG-1_Protein
module add u18/gromacs/2021.5-plumed-avx512-ambertools-mmPBSA

gmx_mpi_MMPBSA -nogui -O -i ../../../mmpbsa.in -cs ../../../md_0_10_1.tpr -ct ../../../md_20ns_nojump.xtc -ci ../../../index.ndx -cg 1 13 -cp ../../../topol.top -o FINAL_RESULTS_MMPBSA.dat -eo FINAL_RESULTS_MMPBSA.csv
cd ../
mkdir LIG-2_Protein
cd LIG-2_Protein
gmx_mpi_MMPBSA -nogui -O -i ../../../mmpbsa.in -cs ../../../md_0_10_1.tpr -ct ../../../md_20ns_nojump.xtc -ci ../../../index.ndx -cg 1 14 -cp ../../../topol.top -o FINAL_RESULTS_MMPBSA_1.dat -eo FINAL_RESULTS_MMPBSA_1.csv
echo done
