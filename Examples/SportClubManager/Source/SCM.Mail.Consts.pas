{-------------------------------------------------------------------------------
   Copyright 2012-2026 Ethea S.r.l.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-------------------------------------------------------------------------------}

/// <summary>SMTP constants used when the application runs on localhost or is built in
/// DEBUG, where every message is redirected to a single mailbox.</summary>
unit SCM.Mail.Consts;

interface

//unit holding the mail sending constants
const
  //sending constants
  CONST_SMTP_Host = 'mail.sportclubmanager.it';
  CONST_SMTP_Username = 'demo@sportclubmanager.it';
  CONST_SMTP_Password = 'jT26M77tF66Q4';
  CONST_SMTP_Port = 587;
  CONST_SMTP_UseTLS = True;
  CONST_SMTP_TLSMode = 'Require';   // Implicit, Require, Explicit

  //receiving constants
  CONST_MAIL = 'carlo.barazzetta@gmail.com';

implementation

end.
