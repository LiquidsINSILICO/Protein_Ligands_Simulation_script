#!/bin/bash
source /home/sudip/gmx_2018-3.env
cp ./../BRP-187/BRP18/3o8y_prot_chainB.pdb .
cp -r ../BRP-187/BRP18/charmm36-jul2021.ff/ .
gmx pdb2gmx -f 3o8y_prot_chainB.pdb -o 3o8y_prot_chainB.gro << EOF
1
1
EOF
#python cgenff_charmm2gmx.py JZ4 jz4_fix.mol2 jz4.str charmm36-mar2019.ff
gmx editconf -f cj13_ini.pdb -o cj13.gro
cp 3o8y_prot_chainB.gro complex.gro
cp ../BRP-187/BRP18/make_complex.f90 .
cp ../BRP-187/BRP18/read.dat .
sed -i 's/brp187.gro/cj13.gro/g' read.dat
gfortran make_complex.f90
./a.out
# Change here based on ligand the number 
num1=10760
num2=51
add=$(($num1 + $num2))
sed "2s/${num1}/${add}/" complex.gro > complex_new.gro 
sed '/^; Include water topology*/i ; Include ligand topology \n#include "cj13.itp"\n' topol.top > sed.out
sed '22 a ; Include ligand parameters \n#include "cj13.prm"\n' sed.out > sed_1.out
#sed "/^Protein_chain_B*/a CJ13\t\t1" sed_1.out > sed_2.out
#sed "101967 a CJ13\t1" sed_1.out > sed_2.out
sed -e '/Protein_chain_B     1/ s/$/\nCJ13     1/' sed_1.out > sed_2.out
mv topol.top '#topol.top.cj13#'
mv sed_2.out topol.top
gmx editconf -f complex_new.gro -o complex_newbox.gro -c -d 1.0 -bt cubic
gmx solvate -cp complex_newbox.gro -cs spc216.gro -o complex_solv.gro -p topol.top
cp ./../AKBA/ions.mdp .
gmx grompp -f ions.mdp -c complex_solv.gro -p topol.top -o ions.tpr
gmx genion -s ions.tpr -o complex_solv_ions.gro -p topol.top -pname SOD -nname CLA -neutral << EOF
15
EOF
cp ./../AKBA/minim_1.mdp .
gmx grompp -f minim_1.mdp -c complex_solv_ions.gro -p topol.top -o em.tpr
gmx mdrun -v -deffnm em -nt 48 -gpu_id 0
echo Potential | gmx energy -f em.edr -o potential.xvg
gmx make_ndx -f cj13.gro -o index_cj13.ndx << EOF
0 & ! a H*
q
EOF
gmx genrestr -f cj13.gro -n index_cj13.ndx -o posre_cj13.itp -fc 1000 1000 1000 << EOF
3
EOF
sed '/^#include "cj13.itp"/a ; Ligand position restraints \n#ifdef POSRES_LIG \n#include "posre_cj13.itp" \n#endif' topol.top > sed_3.out
#sed -e '/#include "cj13.itp"/ s/$/\n/' sed_3.out > sed_4.out
sed '/#include "cj13.itp"/{G;}' sed_3.out > sed_4.out
mv topol.top '#topol.top.posre#'
mv sed_4.out topol.top
gmx make_ndx -f em.gro -o index.ndx << EOF
1 | 13
15 | 14
name 19 water_and_ions
q
EOF
cp ./../AKBA/nvt.mdp .
sed -i 's/Protein_AKBA/Protein_CJ13/g' nvt.mdp
gmx grompp -f nvt.mdp -c em.gro -r em.gro -p topol.top -n index.ndx -o nvt.tpr
gmx mdrun -v -deffnm nvt -nt 48 -gpu_id 0
echo Temperature | gmx energy -f nvt.edr -o temperature.xvg
cp ./../AKBA/npt.mdp .
sed -i 's/Protein_AKBA/Protein_CJ13/g' npt.mdp
gmx grompp -f npt.mdp -c nvt.gro -t nvt.cpt -r nvt.gro -p topol.top -n index.ndx -o npt.tpr
gmx mdrun -v -deffnm npt -nt 48 -gpu_id 0
echo Pressure | gmx energy -f npt.edr -o pressure.xvg 
echo Energy | gmx energy -f npt.edr -o density.xvg
cp ./../AKBA/md.mdp .
sed -i 's/Protein_AKBA/Protein_CJ13/g' md.mdp
gmx grompp -f md.mdp -c npt.gro -t npt.cpt -p topol.top -n index.ndx -o md_0_10.tpr
gmx mdrun -ntomp 48 -nb gpu -pme gpu -gpu_id 0 -pin on -pinoffset 0 -v -deffnm md_0_10
#echo Finish = `date`
