defmodule Aesir.ZoneServer.Script.Dsl.Quest do
  @moduledoc """
  Quest-log buildins for the script DSL: accept, erase, complete, and swap
  quests through the session seam, plus pure reads over the ctx snapshot.

  Imported into scripts via the `Aesir.ZoneServer.Script.Dsl` facade.
  """

  import Aesir.ZoneServer.Script.Dsl.Internal, only: [apply_op: 2, no_player!: 1]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Player.QuestLog

  @doc """
  Accepts quest `quest_id` through the session seam (`setquest`, `quest_add`).
  Halts `:already_started`/`:unknown_quest` when the quest is already held or
  absent from `quest_db`, leaving the log untouched.
  """
  @spec setquest(Ctx.t(), QuestLog.quest_id()) :: Ctx.t()
  def setquest(%Ctx{status: {:error, _}} = ctx, _quest_id), do: ctx
  def setquest(%Ctx{} = ctx, quest_id), do: apply_op(ctx, {:setquest, quest_id})

  @doc """
  Removes quest `quest_id` from the log through the session seam (`erasequest`,
  `quest_delete`). Halts `:not_started` when the quest isn't held.
  """
  @spec erasequest(Ctx.t(), QuestLog.quest_id()) :: Ctx.t()
  def erasequest(%Ctx{status: {:error, _}} = ctx, _quest_id), do: ctx
  def erasequest(%Ctx{} = ctx, quest_id), do: apply_op(ctx, {:erasequest, quest_id})

  @doc """
  Forces quest `quest_id` to `:complete` through the session seam
  (`completequest`, `quest_update_status`), preserving its counters. Halts
  `:not_started` when the quest isn't active/inactive.
  """
  @spec completequest(Ctx.t(), QuestLog.quest_id()) :: Ctx.t()
  def completequest(%Ctx{status: {:error, _}} = ctx, _quest_id), do: ctx
  def completequest(%Ctx{} = ctx, quest_id), do: apply_op(ctx, {:completequest, quest_id})

  @doc """
  Atomically swaps active/inactive quest `old_id` for fresh quest `new_id`
  through the session seam (`changequest`, `quest_change`). Halts on any of
  `QuestLog.change/3`'s error reasons, leaving the log untouched.
  """
  @spec changequest(Ctx.t(), QuestLog.quest_id(), QuestLog.quest_id()) :: Ctx.t()
  def changequest(%Ctx{status: {:error, _}} = ctx, _old_id, _new_id), do: ctx

  def changequest(%Ctx{} = ctx, old_id, new_id),
    do: apply_op(ctx, {:changequest, old_id, new_id})

  @doc """
  Checks quest `quest_id`'s state, `mode` defaulting to `:havequest`
  (`checkquest`, `QuestLog.check/3`). Pure read over the ctx snapshot; a
  never-started quest returns `-1` - the normal "not started yet" branch, not
  an error.
  """
  @spec checkquest(Ctx.t(), QuestLog.quest_id(), :havequest | :playtime | :hunting) ::
          -1 | 0 | 1 | 2
  def checkquest(ctx, quest_id, mode \\ :havequest)
  def checkquest(%Ctx{game_state: nil}, _quest_id, _mode), do: no_player!("checkquest/3")

  def checkquest(%Ctx{game_state: gs}, quest_id, mode),
    do: QuestLog.check(gs.quest_log, quest_id, mode)

  @doc """
  Alias of `checkquest/2,3` over the same `QuestLog.check/3` core (rAthena
  `questprogress`).
  """
  @spec questprogress(Ctx.t(), QuestLog.quest_id(), :havequest | :playtime | :hunting) ::
          -1 | 0 | 1 | 2
  def questprogress(ctx, quest_id, mode \\ :havequest)
  def questprogress(%Ctx{} = ctx, quest_id, mode), do: checkquest(ctx, quest_id, mode)

  @doc """
  Whether quest `quest_id` has been begun: `0` never, `1` inactive/active, `2`
  complete (`isbegin_quest`, `QuestLog.is_begin/2`).
  """
  @spec isbegin_quest(Ctx.t(), QuestLog.quest_id()) :: 0 | 1 | 2
  def isbegin_quest(%Ctx{game_state: nil}, _quest_id), do: no_player!("isbegin_quest/2")
  def isbegin_quest(%Ctx{game_state: gs}, quest_id), do: QuestLog.is_begin(gs.quest_log, quest_id)
end
