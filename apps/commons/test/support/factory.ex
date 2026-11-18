defmodule Aesir.Factory do
  @moduledoc """
  ExMachina factories for the persisted `Aesir.Commons.Models` schemas.

  Each factory builds the smallest valid row and leaves every other column at its schema
  default, so a test states only the fields it cares about:

      import Aesir.Factory

      character = insert(:character, class: 4012, base_level: 99)
      insert(:inventory_item, character: character, nameid: 1201)

  Parent rows are built through `belongs_to` associations and inserted together with the
  child, so `insert(:homunculus)` also inserts its character and account. Pass an existing
  parent (`character: character`) to attach to it instead.

  Identity fields (userid, email, character, guild and party names) combine Faker output
  with an ExMachina sequence, so they never hit a unique constraint.

  Rows are inserted as structs, bypassing changesets. `user_pass` is stored as given, so a
  test that authenticates through `Aesir.Commons.Auth` must set a bcrypt hash itself.
  """

  use ExMachina.Ecto, repo: Aesir.Repo

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.CartItem
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.CharacterStatus
  alias Aesir.Commons.Models.Guild
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.Party
  alias Aesir.Commons.Models.Pet
  alias Aesir.Commons.Models.StorageItem

  @red_potion 501

  @doc "An active account with a plain-text password."
  @spec account_factory() :: Account.t()
  def account_factory do
    %Account{
      userid: sequence(:userid, &"#{String.slice(Faker.Internet.user_name(), 0, 15)}#{&1}"),
      user_pass: "password",
      email: sequence(:email, &"#{&1}.#{Faker.Internet.email()}")
    }
  end

  @doc "A level 1 Novice in slot 0 of its own account."
  @spec character_factory() :: Character.t()
  def character_factory do
    %Character{
      account: build(:account),
      char_num: 0,
      name: sequence(:character_name, &"#{alpha(Faker.Person.first_name(), 15)}_#{&1}"),
      class: 0
    }
  end

  @doc "One identified Red Potion in a character's inventory."
  @spec inventory_item_factory() :: InventoryItem.t()
  def inventory_item_factory do
    %InventoryItem{character: build(:character), nameid: @red_potion, amount: 1, identify: 1}
  end

  @doc "One identified Red Potion in a character's cart."
  @spec cart_item_factory() :: CartItem.t()
  def cart_item_factory do
    %CartItem{character: build(:character), nameid: @red_potion, amount: 1, identify: 1}
  end

  @doc "One identified Red Potion in an account's storage."
  @spec storage_item_factory() :: StorageItem.t()
  def storage_item_factory do
    %StorageItem{account: build(:account), nameid: @red_potion, amount: 1, identify: 1}
  end

  @doc "An active level 1 Lif with its base stats from the species db."
  @spec homunculus_factory() :: Homunculus.t()
  def homunculus_factory do
    %Homunculus{
      character: build(:character),
      class_id: 6_001,
      name: "Lif",
      hp: 150,
      max_hp: 150,
      sp: 40,
      max_sp: 40,
      str: 17,
      agi: 20,
      vit: 15,
      int: 35,
      dex: 24,
      luk: 12
    }
  end

  @doc "A persisted SC row; `status_type` is the lowercase status name, as saved at runtime."
  @spec character_status_factory() :: CharacterStatus.t()
  def character_status_factory do
    %CharacterStatus{character: build(:character), status_type: "sc_blessing", val1: 10}
  end

  @doc "A level 1 guild. `master_char_id` has no foreign key; set it when the test reads it."
  @spec guild_factory() :: Guild.t()
  def guild_factory do
    %Guild{
      name: sequence(:guild_name, &"#{Faker.Team.creature()} #{&1}"),
      master_char_id: 1
    }
  end

  @doc "A party with sharing off. `leader_char_id` has no foreign key; set it when the test reads it."
  @spec party_factory() :: Party.t()
  def party_factory do
    %Party{
      name: sequence(:party_name, &"#{Faker.Team.creature()} #{&1}"),
      leader_char_id: 1
    }
  end

  @doc "An unhatched Poring egg (owner ids 0), the state a pet has while it is an item."
  @spec pet_factory() :: Pet.t()
  def pet_factory do
    %Pet{
      class: 1002,
      name: "Poring",
      account_id: 0,
      char_id: 0,
      level: 1,
      egg_id: 9_001,
      intimate: 250,
      hungry: 100
    }
  end

  defp alpha(text, max), do: text |> String.replace(~r/[^A-Za-z]/, "") |> String.slice(0, max)
end
