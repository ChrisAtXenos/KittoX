{-------------------------------------------------------------------------------
   Copyright 2012-2026 Ethea S.r.l.

   This file is part of KittoX Enterprise Edition.
   Licensed under the AGPL-3.0 or Ethea Commercial License.
   See LICENSE-ENTERPRISE for details.
-------------------------------------------------------------------------------}

/// <summary>
///   Attribute-routed handler for calendar data requests. Returns a JSON array
///   of events (FullCalendar format) for CalendarPanel controllers, optionally
///   filtered by the visible date range.
/// </summary>
unit Kitto.Web.Handler.Calendar;

{$I Kitto.Defines.inc}
{$RTTI EXPLICIT METHODS([vcPublic, vcPublished]) PROPERTIES([vcPublic, vcPublished])}

interface

uses
  Kitto.Web.Routing.Attributes,
  Kitto.Metadata.DataView;

type
  /// <summary>Serves the calendar-data endpoint for a data view configured with
  /// a CalendarPanel controller.</summary>
  [TKXPath('/kx/view/{ViewName}')]
  TKXCalendarHandler = class
  public
    /// <summary>Loads the view's records (filtered to the start/end date range
    /// when both query params are supplied) and returns them as a JSON array of
    /// calendar events with id, title, start/end, color and key metadata.</summary>
    [TKXPath('/calendar-data')]
    [TKXGET]
    procedure HandleCalendarData(
      [TKXPathParam('ViewName')] const AViewName: string;
      [TKXQueryParam('start')] const AStartParam: string;
      [TKXQueryParam('end')] const AEndParam: string;
      [TKXContext] ADataView: TKDataView);
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  System.NetEncoding,
  System.DateUtils,
  Data.DB,
  EF.Tree,
  EF.DB,
  EF.SQL,
  Kitto.SQL,
  Kitto.Config,
  Kitto.Metadata.Views,
  Kitto.Store,
  Kitto.Web.Request,
  Kitto.Web.Response,
  Kitto.Html.DataPanel,
  Kitto.Html.CalendarPanel,
  Kitto.Web.Routing.Registry;

procedure TKXCalendarHandler.HandleCalendarData(const AViewName: string;
  const AStartParam, AEndParam: string; ADataView: TKDataView);
var
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LModelNode: TEFNode;
  LCalendarIdField, LStartDateField, LEndDateField: string;
  LTitleField, LEventTypeField, LEventNotesField: string;
  LHasDateRange: Boolean;
  LStartViewField, LEndViewField: TKViewField;
  LStartExpr, LEndExpr: string;
  LDBConnection: TEFDBConnection;
  LDBQuery: TEFDBQuery;
  LCommandText, LDateFilter, LFilterExpr: string;
  I, J: Integer;
  LRecord: TKViewTableRecord;
  LRecordField: TKViewTableField;
  LIdValue, LTitleValue, LStartValue, LEndValue, LTypeValue, LNotesValue: string;
  LKeyString: string;
  LKeyField: TKViewField;
  LFmt: TFormatSettings;
  LStartDT: TDateTime;
  LDefaultMinutes: Integer;
  LEventTypesMap: TDictionary<string, Integer>;
  LTypeIdx: Integer;
  LColor: string;
  SB, SBKey: TStringBuilder;

  // Binds a date-range parameter of the query built above. SetCommandText has
  // already parsed the SQL and created :cal_start / :cal_end
  // (TEFDBFDQuery.SetCommandText -> TParams.ParseSQL), so the parameter is
  // looked up first and created only if this adapter did not. Creating it
  // unconditionally produced a second, NULL parameter with the same name:
  // ParamByName fills only the first, and since r424 (a NULL TParam is bound
  // as NULL instead of being skipped) the null twin cleared the value on its
  // way to the driver -- the calendar query returned no rows, with no error.
  procedure SetDateParam(const AName: string; const AValue: TDateTime);
  var
    LParam: TParam;
  begin
    LParam := LDBQuery.Params.FindParam(AName);
    if LParam = nil then
      LParam := LDBQuery.Params.CreateParam(ftDateTime, AName, ptInput);
    LParam.AsDateTime := AValue;
  end;

begin
  Assert(Assigned(ADataView), 'ADataView Assigned');
  Assert(Assigned(ADataView.MainTable), 'ADataView.MainTable Assigned');

  LViewTable := ADataView.MainTable;

  // Read calendar field mappings
  LModelNode := ADataView.FindNode('MainTable/Model');
  if Assigned(LModelNode) then
  begin
    LCalendarIdField := LModelNode.GetString('CalendarId', '');
    LStartDateField := LModelNode.GetString('CalendarStartDate', 'StartDate');
    LEndDateField := LModelNode.GetString('CalendarEndDate', 'EndDate');
    LTitleField := LModelNode.GetString('CalendarTitle', 'Title');
    LEventTypeField := LModelNode.GetString('CalendarEventType', 'EventType');
    LEventNotesField := LModelNode.GetString('CalendarEventNotes', 'EventNotes');
  end
  else
  begin
    LStartDateField := 'StartDate';
    LEndDateField := 'EndDate';
    LTitleField := 'Title';
    LEventTypeField := 'EventType';
    LEventNotesField := 'EventNotes';
    LCalendarIdField := '';
  end;

  if LViewTable.FindFieldByAliasedName(LEventNotesField) = nil then
    LEventNotesField := '';

  if LCalendarIdField = '' then
    for I := 0 to LViewTable.FieldCount - 1 do
      if LViewTable.Fields[I].IsKey then
      begin
        LCalendarIdField := LViewTable.Fields[I].AliasedName;
        Break;
      end;

  LHasDateRange := (AStartParam <> '') and (AEndParam <> '');

  if LHasDateRange then
  begin
    LStartViewField := LViewTable.FindFieldByAliasedName(LStartDateField);
    LEndViewField := LViewTable.FindFieldByAliasedName(LEndDateField);
    if Assigned(LStartViewField) then
      LStartExpr := LStartViewField.ModelField.DBColumnNameOrExpression
    else
      LStartExpr := LStartDateField;
    if Assigned(LEndViewField) then
      LEndExpr := LEndViewField.ModelField.DBColumnNameOrExpression
    else
      LEndExpr := LEndDateField;
    LStartExpr := StringReplace(LStartExpr, '{Q}',
      LViewTable.Model.DBTableName + '.', [rfReplaceAll]);
    LEndExpr := StringReplace(LEndExpr, '{Q}',
      LViewTable.Model.DBTableName + '.', [rfReplaceAll]);
  end;

  LFmt := TFormatSettings.Create;
  LFmt.DateSeparator := '-';
  LFmt.TimeSeparator := ':';
  LFmt.ShortDateFormat := 'yyyy-mm-dd';
  LFmt.LongTimeFormat := 'hh:nn:ss';

  // Duration given to an event that has no end, or whose end equals its start
  // (a point-in-time record such as a party, whose model carries a single
  // date/time). Without it the week/day views draw a zero-height strip where
  // only the time fits. Read from the CalendarPanel node (CenterController) with
  // a fallback on the Controller node; minutes, default 60.
  LDefaultMinutes := ADataView.GetInteger('Controller/CenterController/DefaultEventMinutes',
    ADataView.GetInteger('Controller/DefaultEventMinutes', 60));
  if LDefaultMinutes <= 0 then
    LDefaultMinutes := 60;

  LEventTypesMap := TDictionary<string, Integer>.Create;
  LStore := LViewTable.CreateStore;
  SB := TStringBuilder.Create;
  SBKey := TStringBuilder.Create;
  try
    LDBConnection := TKConfig.DatabaseFor(LViewTable.DatabaseName);
    LDBQuery := LDBConnection.CreateDBQuery;
    try
      TKSQLBuilder.CreateAndExecute(
        procedure (ASQLBuilder: TKSQLBuilder)
        begin
          ASQLBuilder.BuildSelectQuery(LViewTable, '', '', LDBQuery, nil);
        end);

      LCommandText := LDBQuery.CommandText;
      if LHasDateRange then
      begin
        if LEndDateField <> LStartDateField then
          LDateFilter := '(' + LStartExpr + ' < :cal_end) and ' +
            '((' + LEndExpr + ' >= :cal_start) or (' + LEndExpr + ' is null))'
        else
          LDateFilter := '(' + LStartExpr + ' < :cal_end) and ' +
            '(' + LStartExpr + ' >= :cal_start)';
        LCommandText := AddToSQLWhereClause(LCommandText, LDateFilter);
      end;
      // The hosting List's filter panel applies to the calendar as to every
      // other presenter: its current values travel as f_N request fields.
      LFilterExpr := BuildRequestFilterExpression(ADataView.FindNode('Controller'));
      if LFilterExpr <> '' then
        LCommandText := AddToSQLWhereClause(LCommandText, LFilterExpr);
      if LHasDateRange or (LFilterExpr <> '') then
        LDBQuery.CommandText := LCommandText;
      if LHasDateRange then
      begin
        SetDateParam('cal_start',
          StrToDateTime(StringReplace(Copy(AStartParam, 1, 19), 'T', ' ', []), LFmt));
        SetDateParam('cal_end',
          StrToDateTime(StringReplace(Copy(AEndParam, 1, 19), 'T', ' ', []), LFmt));
      end;

      LStore.Load(LDBQuery, False, False, nil);
    finally
      FreeAndNil(LDBQuery);
    end;

    SB.Append('[');
    for I := 0 to LStore.RecordCount - 1 do
    begin
      LRecord := LStore.Records[I];
      if I > 0 then
        SB.Append(',');

      LRecordField := LRecord.FindField(LCalendarIdField);
      if Assigned(LRecordField) and not LRecordField.IsNull then
        LIdValue := LRecordField.AsString
      else
        LIdValue := IntToStr(I);

      LRecordField := LRecord.FindField(LTitleField);
      if Assigned(LRecordField) and not LRecordField.IsNull then
        LTitleValue := LRecordField.AsString
      else
        LTitleValue := '';

      LRecordField := LRecord.FindField(LStartDateField);
      if Assigned(LRecordField) and not LRecordField.IsNull then
      begin
        LStartDT := LRecordField.AsDateTime;
        LStartValue := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', LStartDT, LFmt);
      end
      else
      begin
        LStartDT := 0;
        LStartValue := '';
      end;

      LRecordField := LRecord.FindField(LEndDateField);
      if Assigned(LRecordField) and not LRecordField.IsNull
        and (LRecordField.AsDateTime > LStartDT) then
        LEndValue := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', LRecordField.AsDateTime, LFmt)
      else if LStartValue <> '' then
        // No end, or end = start: give the event the default duration.
        LEndValue := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss',
          IncMinute(LStartDT, LDefaultMinutes), LFmt)
      else
        LEndValue := '';

      LNotesValue := '';
      if LEventNotesField <> '' then
      begin
        LRecordField := LRecord.FindField(LEventNotesField);
        if Assigned(LRecordField) and not LRecordField.IsNull then
          LNotesValue := LRecordField.AsString;
      end;

      LColor := '#1a73e8';
      LRecordField := LRecord.FindField(LEventTypeField);
      if Assigned(LRecordField) and not LRecordField.IsNull then
      begin
        LTypeValue := LRecordField.AsString;
        if not LEventTypesMap.TryGetValue(LTypeValue, LTypeIdx) then
        begin
          LTypeIdx := LEventTypesMap.Count;
          LEventTypesMap.Add(LTypeValue, LTypeIdx);
        end;
        LColor := TKXCalendarPanelController.CALENDAR_COLORS[
          LTypeIdx mod Length(TKXCalendarPanelController.CALENDAR_COLORS)];
      end;

      SBKey.Clear;
      for J := 0 to LViewTable.FieldCount - 1 do
      begin
        LKeyField := LViewTable.Fields[J];
        if LKeyField.IsKey then
        begin
          LRecordField := LRecord.FindField(LKeyField.AliasedName);
          if Assigned(LRecordField) then
          begin
            if SBKey.Length > 0 then
              SBKey.Append('&');
            SBKey.Append(TNetEncoding.URL.Encode(LKeyField.AliasedName));
            SBKey.Append('=');
            SBKey.Append(TNetEncoding.URL.Encode(LRecordField.AsString));
          end;
        end;
      end;
      LKeyString := SBKey.ToString;

      SB.Append('{');
      SB.Append('"id":').Append(TKXCalendarPanelController.JSONStr(LIdValue));
      SB.Append(',"title":').Append(TKXCalendarPanelController.JSONStr(LTitleValue));
      if LStartValue <> '' then
        SB.Append(',"start":').Append(TKXCalendarPanelController.JSONStr(LStartValue));
      if LEndValue <> '' then
        SB.Append(',"end":').Append(TKXCalendarPanelController.JSONStr(LEndValue));
      SB.Append(',"backgroundColor":').Append(TKXCalendarPanelController.JSONStr(LColor));
      SB.Append(',"extendedProps":{"key":').Append(TKXCalendarPanelController.JSONStr(LKeyString));
      if LNotesValue <> '' then
        SB.Append(',"notes":').Append(TKXCalendarPanelController.JSONStr(LNotesValue));
      SB.Append('}');
      SB.Append('}');
    end;
    SB.Append(']');

    TKWebResponse.Current.Items.Clear;
    TKWebResponse.Current.Items.AddHTML(SB.ToString);
    TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
  finally
    SBKey.Free;
    SB.Free;
    FreeAndNil(LStore);
    LEventTypesMap.Free;
  end;
end;

initialization
  TKXResourceRegistry.Instance.RegisterResource(TKXCalendarHandler);

finalization
  TKXResourceRegistry.Instance.UnregisterResource(TKXCalendarHandler);

end.
