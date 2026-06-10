{\rtf1\ansi\ansicpg950\cocoartf2870
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;\f1\fmodern\fcharset0 Courier;}
{\colortbl;\red255\green255\blue255;\red0\green0\blue0;\red255\green255\blue255;}
{\*\expandedcolortbl;;\cssrgb\c0\c0\c0;\cssrgb\c100000\c100000\c99971;}
\paperw11900\paperh16840\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 # CLAUDE.md\
\
\pard\pardeftab720\partightenfactor0

\f1\fs26 \cf2 \expnd0\expndtw0\kerning0
## Model Usage Strategy\
\
Use Claude Fable only for high-leverage reasoning checkpoints:\
\
- brainstorming\
- API feasibility analysis\
- compliance boundary definition\
- product spec\
- architecture decisions\
- first implementation plan\
- plan review\
- final security/compliance/code review\
- root-cause debugging when Sonnet gets stuck\
\
Use Claude Sonnet for execution:\
\
- SwiftUI implementation\
- API client implementation after feasibility is clear\
- Keychain integration\
- local persistence\
- reusable components\
- tests\
- README\
- small bug fixes\
- implementation plan execution\
\
Do not use Fable for routine coding once the plan is clear.\
Escalate from Sonnet to Fable only when the implementation reveals a product, architecture, API, security, or compliance problem.}