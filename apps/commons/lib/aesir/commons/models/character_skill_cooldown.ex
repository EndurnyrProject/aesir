defmodule Aesir.Commons.Models.CharacterSkillCooldown do
  @moduledoc """
  A character's skill cooldown saved at logout, mirroring rAthena's
  `skillcooldown` table.

  `remaining_ms` is the cooldown time left when the character logged out.
  Rows are written on logout and consumed (loaded then deleted) on login, so
  the table only holds cooldowns of characters that are currently offline,
  and time spent offline does not run them down.
  """

  use Ecto.Schema

  alias Aesir.Commons.Models.Character

  @type t :: %__MODULE__{
          char_id: integer() | nil,
          skill_id: integer() | nil,
          remaining_ms: integer() | nil,
          character: Character.t() | Ecto.Association.NotLoaded.t()
        }

  @primary_key false
  schema "character_skill_cooldowns" do
    belongs_to :character, Character, foreign_key: :char_id, primary_key: true
    field :skill_id, :integer, primary_key: true
    field :remaining_ms, :integer
  end
end
