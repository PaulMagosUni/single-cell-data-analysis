library(dplyr)
library(Seurat)
library(patchwork)
library(DropletUtils)
source("utils.R")

DATASETS_FOLDER = './dataset/'
NAME = 'tabula-muris-marrow_P7_3'
CHANNEL = '10X_P7_3'

inDataDir  = paste(DATASETS_FOLDER, NAME, sep='')
outDataDir = paste(DATASETS_FOLDER, NAME, '-filtered/', sep='') 

# Loading data
data = Read10X(data.dir = inDataDir)
colnames(data) = substr(colnames(data), 1, 16)

# Load the PBMC dataset
pbmc.data <- data

# plot distribution of amount of cells in which each gene is expressed
ggplot(data.frame("sum" = rowSums(pbmc.data > 0)), aes(x=sum)) + geom_histogram()
# plot distribution of sum of counts for each cell
ggplot(data.frame("sum" = colSums(pbmc.data > 0)), aes(x=sum)) + geom_histogram()

# Initialize the Seurat object with the raw (non-normalized data).
pbmc <- CreateSeuratObject(counts = pbmc.data, project = "pbmc3k", min.cells = 3, min.features = 200)

# The [[ operator can add columns to object metadata. This is a great place to stash QC stats
pbmc[["percent.mt"]] <- PercentageFeatureSet(pbmc, pattern = "^Mt")

# Visualize QC metrics as a violin plot
VlnPlot(pbmc, features = c("nFeature_RNA", "nCount_RNA", "percent.mt"), ncol = 3)

# FeatureScatter is typically used to visualize feature-feature relationships, but can be used
# for anything calculated by the object, i.e. columns in object metadata, PC scores etc.

plot1 <- FeatureScatter(pbmc, feature1 = "nCount_RNA", feature2 = "percent.mt")
plot2 <- FeatureScatter(pbmc, feature1 = "nCount_RNA", feature2 = "nFeature_RNA")
plot1 + plot2


# Set very loose limits for COTAN
pbmc <- subset(pbmc, subset = nFeature_RNA > 0 & nFeature_RNA < 6000 & percent.mt < 5)



# Write pre-processed data
data_to_write = GetAssayData(object = pbmc, assay = "RNA", slot = "data")

write.csv(data_to_write, paste(outDataDir, "data.csv", sep=""))
Dir10X = paste(outDataDir, "10X", sep="")
if (!dir.exists(Dir10X)) {
  write10xCounts(Dir10X, data_to_write)
}

metadata = read.csv(paste(inDataDir, "/annotations_droplet.csv", sep=""))
metadata = metadata[metadata$channel == CHANNEL, c("cell", "cell_ontology_class", "cluster.ids")]
metadata$cell = substr(metadata$cell, 10, 25)
labels = sort(unique(metadata$cell_ontology_class))
metadata$cluster.ids = match(metadata$cell_ontology_class, labels)

filtered_labels = merge(data.frame("cell"=colnames(data_to_write)), metadata)
write.csv(filtered_labels[,c('cell', 'cluster.ids')], paste(outDataDir, "labels.csv", sep=""), row.names = FALSE)


mapping = data.frame("go"=labels, "id"=1:length(labels))
write.csv(mapping, paste(outDataDir, "mapping.csv", sep=""), row.names = FALSE)
