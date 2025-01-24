from setuptools import setup, find_packages

setup(
    name="spenzy-common",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[
        "python-keycloak>=3.0.0",
        "grpcio>=1.68.0",
        "grpcio-tools>=1.68.0",
    ],
) 