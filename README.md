# Omics-Dashboard-MATLAB-Client
A collection of MATLAB scripts for interfacing with a BiRG/Omics-Dashboard service.

Communication is limited to getting and posting collections. Please use the [python client](https://github.com/BiRG/Omics-Dashboard-Python-Client) to manage other records.

## Usage
```matlab
session = OmicsDashboardSession('https://example.com/omics')

% access collection #12
collection = session.get_collection(12)

% access collection attribute
collection_name = collection.name

% post collection and attach to analysis 14
session.post_collection(collection, 14)
```
