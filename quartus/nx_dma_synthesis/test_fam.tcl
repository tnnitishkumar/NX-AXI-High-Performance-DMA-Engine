package require ::quartus::project
project_open nx_dma_synthesis
foreach fam { "Stratix 10" "Agilex 7" "Arria 10" "Cyclone 10 GX" "Stratix V" "MAX 10" } {
    if {[catch {set_global_assignment -name FAMILY $fam} err]} {
        puts "Family $fam not supported: $err"
    } else {
        puts "Family $fam supported!"
    }
}
project_close
