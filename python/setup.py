from setuptools import setup, find_packages

setup(
    name="mlc-llm",
    version="0.1.0",
    description="Python package for MLC LLM runtime",
    packages=find_packages(),
    install_requires=[],
    python_requires=">=3.8",
    entry_points={
        'console_scripts': [
            'mlc_llm=mlc_llm.cli:main',  # Replace with actual module/function
        ],
    },
)
