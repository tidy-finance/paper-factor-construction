# Response to the editor and referees

We thank the handling editor and the referees for their careful reading and constructive comments. Below we reply to each comment in turn. Comments are quoted, followed by our response.

## Handling editor

> Just getting a WRDS account alone was not sufficient, I needed to enable 2FA and also accept terms and conditions. [...] You may like to document this somewhere -- it doesn't necessary have to be in the paper (or you may already do).

Thank you for pointing this out. We now document the WRDS account prerequisites in both the package and the paper:

- **Package.** The help pages `?get_wrds_connection` and `?set_wrds_credentials`, the package vignette, and the README now contain a WRDS account setup checklist: obtain an account, enroll in two-factor authentication (Duo), accept the WRDS terms of use on the WRDS website, store credentials with `set_wrds_credentials()`, and approve the Duo push notification when connecting. In addition, `get_wrds_connection()` now catches failed connection attempts and rethrows them with these hints instead of the raw database error.
- **Paper.** The WRDS paragraph in the data section now states that credentials alone do not suffice, that users must enroll in 2FA and accept the WRDS terms of use before the first connection, and refers readers to `?get_wrds_connection` for the full checklist.

## Referee 2

> Pg 20, Stefan Voigt: Maybe add a linebreak, or comma, between U of C and DFI.

Thank you. The two affiliations now appear separated by a comma: "University of Copenhagen, Danish Finance Institute".
